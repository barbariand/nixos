{ lib, ipLib }:
rec {
  isNodeInNetwork = hostName: netCfg:
    builtins.hasAttr hostName netCfg.topology.nodes;

  isHubNode = hostName: netCfg:
    builtins.hasAttr hostName netCfg.topology.hubs;

  isNetworkEnabled = hostName: netCfg:
    netCfg.enable || ((netCfg.autoEnable or false) && (isNodeInNetwork hostName netCfg));

  isNetworkActive = hostName: netCfg:
    (isNetworkEnabled hostName netCfg) && (isNodeInNetwork hostName netCfg);

  resolveHubLinks = hubName: hubCfg: nodes:
    if (hubCfg.links or []) != []
    then hubCfg.links
    else builtins.filter (n: n != hubName) (builtins.attrNames nodes);

  effectiveMode = netCfg:
    if (netCfg.isolated or false)
    then "isolated"
    else netCfg.mode or (if (netCfg.interface or null) != null then "gateway" else "mesh");

  isEffectiveIsolated = netCfg:
    (effectiveMode netCfg) == "isolated";

  trustInterface = netCfg: let
    mode = effectiveMode netCfg;
    explicit = netCfg.firewall.trustInterface or null;
  in
    if explicit != null
    then explicit
    else (mode == "mesh" || mode == "gateway");

  allowPeerToPeer = netCfg: let
    mode = effectiveMode netCfg;
    explicit = netCfg.firewall.allowPeerToPeer or null;
  in
    if explicit != null
    then explicit
    else (mode == "mesh" || mode == "gateway");

  allowExternalRouting = netCfg: let
    mode = effectiveMode netCfg;
    explicit = netCfg.firewall.allowExternalRouting or null;
  in
    if explicit != null
    then explicit
    else ((mode == "mesh" || mode == "gateway") && (netCfg.interface or null) != null);

  allowPing = netCfg: let
    explicit = netCfg.firewall.allowPing or null;
  in
    if explicit != null
    then explicit
    else !(isEffectiveIsolated netCfg);

  isRoutingHub = hostName: netCfg:
    (isHubNode hostName netCfg) && ((allowPeerToPeer netCfg) || (allowExternalRouting netCfg));

  isPolicyHub = hostName: netCfg:
    (isHubNode hostName netCfg)
    && (
      (isEffectiveIsolated netCfg)
      || ((effectiveMode netCfg) == "hub-only")
      || !(trustInterface netCfg)
      || ((netCfg.forwards or []) != [])
    );

  hasCustomNftables = netCfg: let
    nft = netCfg.nftables or {};
  in
    ((nft.extraFilterRules or "") != "")
    || ((nft.extraInputRules or "") != "")
    || ((nft.extraPreroutingRules or "") != "")
    || ((nft.extraPostroutingRules or "") != "")
    || ((nft.extraConfig or "") != "");

  needsNftables = hostName: netCfg:
    (isRoutingHub hostName netCfg)
    || (isPolicyHub hostName netCfg)
    || (hasCustomNftables netCfg);

  isForwardTarget = hostName: netCfg:
    builtins.any (f: f.targetNode == hostName) (netCfg.forwards or []);

  # Hämtar alla målportar som riktas mot denna nod (inklusive cross-network forwards)
  targetPortsForHostInNetwork = protocol: hostName: netName: netCfg: allNetworks: let
    localForwards = builtins.filter (
      f:
        f.targetNode == hostName
        && f.protocol == protocol
        && (f.targetNetwork == null || f.targetNetwork == netName)
    ) (netCfg.forwards or []);

    crossForwards = lib.flatten (lib.mapAttrsToList (
      otherName: otherCfg:
        if otherName == netName
        then []
        else
          builtins.filter (
            f:
              f.targetNode == hostName
              && f.protocol == protocol
              && f.targetNetwork == netName
          ) (otherCfg.forwards or [])
    ) allNetworks);

    extractPort = f: if f.targetPort != null then f.targetPort else f.port;
  in
    lib.unique (map extractPort (localForwards ++ crossForwards));

  targetPortsForHost = protocol: hostName: netCfg:
    targetPortsForHostInNetwork protocol hostName "" netCfg { "" = netCfg; };

  resolvePeers = hostName: netCfg: let
    nodes = netCfg.topology.nodes;
    hubs = netCfg.topology.hubs;

    hubPeers = lib.optionalAttrs (isHubNode hostName netCfg) (
      let
        links = resolveHubLinks hostName hubs.${hostName} nodes;
        validLinks = builtins.filter (l: l != hostName && builtins.hasAttr l nodes) links;
      in
        lib.genAttrs validLinks (linkName:
          {
            publicKey = nodes.${linkName}.publicKey;
            allowedIPs = lib.unique (
              ["${nodes.${linkName}.ip}/32"]
              ++ (nodes.${linkName}.extraAllowedIPs or [])
            );
          }
          // lib.optionalAttrs (builtins.hasAttr linkName hubs) {
            endpoint = "${hubs.${linkName}.endpoint}:${toString hubs.${linkName}.port}";
            persistentKeepalive = hubs.${linkName}.persistentKeepalive or 21;
          }
        )
    );

    uplinkHubs = lib.filterAttrs (
      hName: hCfg:
        hName != hostName
        && builtins.hasAttr hName nodes
        && builtins.elem hostName (resolveHubLinks hName hCfg nodes)
    ) hubs;

    clientPeers = lib.mapAttrs (hName: hCfg: {
      publicKey = nodes.${hName}.publicKey;
      endpoint = "${hCfg.endpoint}:${toString hCfg.port}";
      allowedIPs = lib.unique (
        [(ipLib.calcNetworkAddress nodes.${hName}.ip netCfg.topology.prefixLength)]
        ++ (nodes.${hName}.extraAllowedIPs or [])
        ++ (hCfg.extraAllowedIPs or [])
      );
      persistentKeepalive = hCfg.persistentKeepalive or 21;
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

  getNetworkCidr = netCfg: let
    nodeList = lib.attrValues netCfg.topology.nodes;
  in
    if nodeList == []
    then null
    else ipLib.calcNetworkAddress (builtins.head nodeList).ip netCfg.topology.prefixLength;
}
