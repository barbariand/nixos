{lib}: rec {
  mkForward = port: targetNode: {
    inherit port targetNode;
    targetPort = null;
    targetNetwork = null;
    protocol = "tcp";
    __functor = self: opts:
      builtins.removeAttrs (
        self
        // (
          if builtins.isInt opts
          then {targetPort = opts;}
          else if builtins.isString opts
          then {protocol = opts;}
          else opts
        )
      ) ["__functor"];
  };

  mkForwardUDP = port: targetNode:
    (mkForward port targetNode) "udp";

  exposeService = port: targetNode: {
    isolated = true;
    forwards = [(mkForward port targetNode)];
    __functor = self: extra:
      builtins.removeAttrs (self // extra) ["__functor"];
  };

  isNodeInNetwork = hostName: netCfg:
    builtins.hasAttr hostName netCfg.topology.nodes;

  isHubNode = hostName: netCfg:
    builtins.hasAttr hostName netCfg.topology.hubs;

  isRoutingHub = hostName: netCfg:
    (isHubNode hostName netCfg) && (netCfg.interface != null) && (!netCfg.isolated);

  isPolicyHub = hostName: netCfg:
    (isHubNode hostName netCfg) && (netCfg.isolated || netCfg.forwards != []);

  isForwardTarget = hostName: netCfg:
    builtins.any (f: f.targetNode == hostName) netCfg.forwards;

  targetPortsForHost = protocol: hostName: netCfg:
    lib.pipe netCfg.forwards [
      (builtins.filter (f: f.targetNode == hostName && f.protocol == protocol))
      (map (f: if f.targetPort != null then f.targetPort else f.port))
      lib.unique
    ];

  resolvePeers = hostName: netCfg: let
    nodes = netCfg.topology.nodes;
    hubs = netCfg.topology.hubs;

    hubPeers = lib.optionalAttrs (isHubNode hostName netCfg) (
      lib.genAttrs hubs.${hostName}.links (linkName: {
        publicKey = nodes.${linkName}.publicKey;
        allowedIPs = ["${nodes.${linkName}.ip}/32"];
      })
    );

    uplinkHubs = lib.filterAttrs (_: hCfg: builtins.elem hostName hCfg.links) hubs;

    clientPeers = lib.mapAttrs (hName: hCfg: {
      publicKey = nodes.${hName}.publicKey;
      endpoint = "${hCfg.endpoint}:${toString hCfg.port}";
      # systemd-networkd requires subnet routing via the hub IP
      allowedIPs = ["${nodes.${hName}.ip}/${toString netCfg.topology.prefixLength}"];
      persistentKeepalive = 21;
    }) uplinkHubs;
  in
    lib.attrValues (hubPeers // clientPeers);

  mkInterfaceConfig = hostName: netCfg: let
    localNode = netCfg.topology.nodes.${hostName};
    isHub = isHubNode hostName netCfg;
  in {
    listenPort = if isHub then netCfg.topology.hubs.${hostName}.port else null;
    privateKeyFile = netCfg.privateKeyFile;
    ips = ["${localNode.ip}/${toString netCfg.topology.prefixLength}"];
    peers = resolvePeers hostName netCfg;
  };

  mkRoutingTable = netName: netCfg: ''
    chain forward {
      type filter hook forward priority filter; policy accept;
      ct state established,related accept
      iifname "${netName}" oifname "${netCfg.interface}" counter accept
      iifname "${netName}" oifname "${netName}" counter accept
    }

    chain postrouting {
      type nat hook postrouting priority srcnat; policy accept;
      oifname "${netCfg.interface}" counter masquerade
    }
  '';

  mkPolicyTable = hostName: netName: netCfg: allWgNetworks: let
    nodes = netCfg.topology.nodes;
    localIp = nodes.${hostName}.ip;

    resolveTargetNode = fwd:
      if fwd.targetNetwork != null
      then allWgNetworks.${fwd.targetNetwork}.topology.nodes.${fwd.targetNode}
      else nodes.${fwd.targetNode};

    resolveOutInterface = fwd:
      if fwd.targetNetwork != null then fwd.targetNetwork else netName;

    resolvePort = fwd:
      if fwd.targetPort != null then toString fwd.targetPort else toString fwd.port;

    preroutingRules = lib.concatMapStringsSep "\n" (fwd: let
      target = resolveTargetNode fwd;
      destPort = resolvePort fwd;
    in "    iifname \"${netName}\" ip daddr ${localIp} ${fwd.protocol} dport ${toString fwd.port} counter dnat to ${target.ip}:${destPort}") netCfg.forwards;

    postroutingRules = lib.concatMapStringsSep "\n" (fwd: let
      target = resolveTargetNode fwd;
      outIf = resolveOutInterface fwd;
      destPort = resolvePort fwd;
    in
      # Masquerade so replies return through the hub instead of asymmetric client routing
      "    oifname \"${outIf}\" ip daddr ${target.ip} ${fwd.protocol} dport ${destPort} counter masquerade") netCfg.forwards;

    forwardRules = lib.concatMapStringsSep "\n" (fwd: let
      target = resolveTargetNode fwd;
      outIf = resolveOutInterface fwd;
      destPort = resolvePort fwd;
    in "    iifname \"${netName}\" oifname \"${outIf}\" ip daddr ${target.ip} ${fwd.protocol} dport ${destPort} counter accept") netCfg.forwards;

    forwardPolicy = if netCfg.isolated then "drop" else "accept";
    inputRule = lib.optionalString netCfg.isolated "    iifname \"${netName}\" counter drop";
  in ''
    chain prerouting {
      type nat hook prerouting priority dstnat; policy accept;
${preroutingRules}
    }

    chain postrouting {
      type nat hook postrouting priority srcnat; policy accept;
${postroutingRules}
    }

    chain forward {
      type filter hook forward priority filter - 1; policy ${forwardPolicy};
      ct state established,related accept
${forwardRules}
    }

    chain input {
      type filter hook input priority filter - 1; policy accept;
      ct state established,related accept
${inputRule}
    }
  '';

  mkAssertions = hostName: enabledNetworks: let
    membershipAssertions = lib.mapAttrsToList (netName: netCfg: {
      assertion = isNodeInNetwork hostName netCfg;
      message = "WireGuard network '${netName}' is enabled, but host '${hostName}' is missing from topology.nodes.";
    }) enabledNetworks;

    forwardAssertions = lib.flatten (lib.mapAttrsToList (netName: netCfg:
      map (fwd: let
        targetNodes =
          if fwd.targetNetwork != null
          then (enabledNetworks.${fwd.targetNetwork}.topology.nodes or {})
          else netCfg.topology.nodes;
      in {
        assertion = builtins.hasAttr fwd.targetNode targetNodes;
        message = "WireGuard network '${netName}' forwards port ${toString fwd.port} to unknown node '${fwd.targetNode}'.";
      }) netCfg.forwards
    ) enabledNetworks);
  in
    membershipAssertions ++ forwardAssertions;
}
