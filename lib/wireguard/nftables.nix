{
  lib,
  topologyLib,
}: rec {
  resolveTargetNode = netCfg: allWgNetworks: fwd:
    if fwd.targetNetwork != null
    then allWgNetworks.${fwd.targetNetwork}.topology.nodes.${fwd.targetNode}
    else netCfg.topology.nodes.${fwd.targetNode};

  resolveOutInterface = netName: fwd:
    if fwd.targetNetwork != null
    then fwd.targetNetwork
    else netName;

  resolvePort = fwd:
    if fwd.targetPort != null
    then toString fwd.targetPort
    else toString fwd.port;

  mkNetworkTable = hostName: netName: netCfg: allWgNetworks: let
    nodes = netCfg.topology.nodes;
    localIp = nodes.${hostName}.ip;
    forwards = netCfg.forwards or [];
    nft = netCfg.nftables or {};

    p2p = topologyLib.allowPeerToPeer netCfg;
    extRoute = topologyLib.allowExternalRouting netCfg;
    trusted = topologyLib.trustInterface netCfg;
    isolated = topologyLib.isEffectiveIsolated netCfg;
    mode = topologyLib.effectiveMode netCfg;
    pingAllowed = topologyLib.allowPing netCfg;

    allowedTcp = netCfg.firewall.allowedTCPPorts or [];
    allowedUdp = netCfg.firewall.allowedUDPPorts or [];

    preroutingRules =
      lib.concatMapStringsSep "\n" (
        fwd: let
          target = resolveTargetNode netCfg allWgNetworks fwd;
          destPort = resolvePort fwd;
        in "    iifname \"${netName}\" ip daddr ${localIp} ${fwd.protocol} dport ${toString fwd.port} counter dnat to ${target.ip}:${destPort}"
      )
      forwards;

    dnatPostroutingRules =
      lib.concatMapStringsSep "\n" (
        fwd: let
          target = resolveTargetNode netCfg allWgNetworks fwd;
          outIf = resolveOutInterface netName fwd;
          destPort = resolvePort fwd;
        in "    oifname \"${outIf}\" ip daddr ${target.ip} ${fwd.protocol} dport ${destPort} counter masquerade"
      )
      forwards;

    extMasqueradeRule = lib.optionalString (
      extRoute && netCfg.interface != null
    ) "    iifname \"${netName}\" oifname \"${netCfg.interface}\" counter masquerade";

    p2pForwardRule = lib.optionalString p2p "    iifname \"${netName}\" oifname \"${netName}\" counter accept";

    extForwardRule = lib.optionalString (
      extRoute && netCfg.interface != null
    ) "    iifname \"${netName}\" oifname \"${netCfg.interface}\" counter accept";

    dnatForwardRules =
      lib.concatMapStringsSep "\n" (
        fwd: let
          target = resolveTargetNode netCfg allWgNetworks fwd;
          outIf = resolveOutInterface netName fwd;
          destPort = resolvePort fwd;
        in "    iifname \"${netName}\" oifname \"${outIf}\" ip daddr ${target.ip} ${fwd.protocol} dport ${destPort} counter accept"
      )
      forwards;

    # Kasserar endast otillåten trafik som kommer in via just detta gränssnitt
    forwardDropRule = lib.optionalString (
      !p2p || isolated || mode == "hub-only"
    ) "    iifname \"${netName}\" counter drop";

    pingInputRule = lib.optionalString pingAllowed "    iifname \"${netName}\" icmp type echo-request counter accept";

    tcpInputRule =
      lib.optionalString (allowedTcp != [])
      "    iifname \"${netName}\" tcp dport { ${
        lib.concatMapStringsSep ", " toString allowedTcp
      } } counter accept";

    udpInputRule =
      lib.optionalString (allowedUdp != [])
      "    iifname \"${netName}\" udp dport { ${
        lib.concatMapStringsSep ", " toString allowedUdp
      } } counter accept";

    inputDropRule = lib.optionalString (!trusted) "    iifname \"${netName}\" counter drop";

    hasPrerouting = forwards != [] || (nft.extraPreroutingRules or "") != "";
    hasPostrouting =
      (extRoute && netCfg.interface != null)
      || forwards != []
      || (nft.extraPostroutingRules or "") != "";
    hasInput = !trusted || (nft.extraInputRules or "") != "";

    nonEmptyLines = lines: lib.concatStringsSep "\n" (builtins.filter (l: l != "") lines);
  in
    nonEmptyLines [
      (lib.optionalString hasPrerouting ''
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
        ${nonEmptyLines [
          preroutingRules
          (nft.extraPreroutingRules or "")
        ]}
        }
      '')
      (lib.optionalString hasPostrouting ''
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
        ${nonEmptyLines [
          extMasqueradeRule
          dnatPostroutingRules
          (nft.extraPostroutingRules or "")
        ]}
        }
      '')
      ''
        chain forward {
          type filter hook forward priority filter - 1; policy accept;
          ct state established,related accept
        ${nonEmptyLines [
          p2pForwardRule
          extForwardRule
          dnatForwardRules
          (nft.extraFilterRules or "")
          forwardDropRule
        ]}
        }
      ''
      (lib.optionalString hasInput ''
        chain input {
          type filter hook input priority filter - 1; policy accept;
          ct state established,related accept
        ${nonEmptyLines [
          pingInputRule
          tcpInputRule
          udpInputRule
          (nft.extraInputRules or "")
          inputDropRule
        ]}
        }
      '')
      (nft.extraConfig or "")
    ];

  # Genererar regler för NixOS inbyggda inet nixos-fw forward-kedja så att trafik som
  # redan filtrerats och godkänts av wg_<net>-tabellen inte kasserars av nixos-fw.
  mkFirewallForwardRules = hostName: activeNetworks: let
    hubNets = lib.filterAttrs (_: netCfg: topologyLib.needsNftables hostName netCfg) activeNetworks;
    rules =
      lib.mapAttrsToList (netName: _: ''
        iifname "${netName}" counter accept
        oifname "${netName}" ct state established,related counter accept
      '')
      hubNets;
  in
    lib.concatStringsSep "\n" rules;

  # Bakåtkompatibla hjälpare
  mkRoutingTable = netName: netCfg: ''
    chain forward {
      type filter hook forward priority filter; policy accept;
      ct state established,related accept
      ${lib.optionalString (
      netCfg.interface != null
    ) ''iifname "${netName}" oifname "${netCfg.interface}" counter accept''}
      iifname "${netName}" oifname "${netName}" counter accept
    }

    ${lib.optionalString (netCfg.interface != null) ''
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        iifname "${netName}" oifname "${netCfg.interface}" counter masquerade
      }
    ''}
  '';

  mkPolicyTable = hostName: netName: netCfg: allWgNetworks:
    mkNetworkTable hostName netName netCfg allWgNetworks;
}
