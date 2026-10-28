{
  lib,
  ipLib,
  topologyLib,
}: {
  mkAssertions = hostName: allNetworks: let
    explicitlyEnabled = lib.filterAttrs (_: v: v.enable) allNetworks;
    activeNetworks = lib.filterAttrs (_: v: topologyLib.isNetworkActive hostName v) allNetworks;

    membershipAssertions =
      lib.mapAttrsToList (netName: netCfg: {
        assertion = topologyLib.isNodeInNetwork hostName netCfg;
        message = "WireGuard network '${netName}' has enable = true on host '${hostName}', but '${hostName}' is missing from topology.nodes (use autoEnable = true if defining globally).";
      })
      explicitlyEnabled;

    ipValidAssertions = lib.flatten (
      lib.mapAttrsToList (
        netName: netCfg:
          lib.mapAttrsToList (nodeName: nodeCfg: {
            assertion = ipLib.isValidIPv4 nodeCfg.ip;
            message = "WireGuard network '${netName}': Node '${nodeName}' has an invalid IPv4 address '${nodeCfg.ip}'.";
          })
          netCfg.topology.nodes
      )
      activeNetworks
    );

    duplicateIpAssertions =
      lib.mapAttrsToList (
        netName: netCfg: let
          ips = lib.mapAttrsToList (_: n: n.ip) netCfg.topology.nodes;
        in {
          assertion = (builtins.length ips) == (builtins.length (lib.unique ips));
          message = "WireGuard network '${netName}' contains duplicate IPv4 addresses in topology.nodes.";
        }
      )
      activeNetworks;

    hubExistenceAssertions = lib.flatten (
      lib.mapAttrsToList (
        netName: netCfg:
          lib.mapAttrsToList (hubName: hubCfg: {
            assertion = builtins.hasAttr hubName netCfg.topology.nodes;
            message = "WireGuard network '${netName}': Hub '${hubName}' must also be defined in topology.nodes.";
          })
          netCfg.topology.hubs
      )
      activeNetworks
    );

    linkAssertions = lib.flatten (
      lib.mapAttrsToList (
        netName: netCfg:
          lib.mapAttrsToList (
            hubName: hubCfg:
              map (linkName: {
                assertion = builtins.hasAttr linkName netCfg.topology.nodes;
                message = "WireGuard network '${netName}': Hub '${hubName}' links to unknown node '${linkName}'.";
              }) (hubCfg.links or [])
          )
          netCfg.topology.hubs
      )
      activeNetworks
    );

    gatewayAssertions =
      lib.mapAttrsToList (netName: netCfg: {
        assertion =
          ((topologyLib.effectiveMode netCfg) == "gateway" && (topologyLib.isHubNode hostName netCfg))
          -> (netCfg.interface != null);
        message = "WireGuard network '${netName}' is in 'gateway' mode on hub '${hostName}', which requires 'interface' (e.g. 'eth0') to be set.";
      })
      activeNetworks;

    forwardAssertions = lib.flatten (
      lib.mapAttrsToList (
        netName: netCfg:
          map (
            fwd: let
              targetNodes =
                if fwd.targetNetwork != null
                then (allNetworks.${fwd.targetNetwork}.topology.nodes or {})
                else netCfg.topology.nodes;
            in {
              assertion = builtins.hasAttr fwd.targetNode targetNodes;
              message = "WireGuard network '${netName}' forwards port ${toString fwd.port} to unknown node '${fwd.targetNode}'${
                lib.optionalString (fwd.targetNetwork != null) " in network '${fwd.targetNetwork}'"
              }.";
            }
          ) (netCfg.forwards or [])
      )
      activeNetworks
    );

    hubPortsOnHost = lib.mapAttrsToList (_: netCfg: netCfg.topology.hubs.${hostName}.port) (
      lib.filterAttrs (_: netCfg: topologyLib.isHubNode hostName netCfg) activeNetworks
    );

    portCollisionAssertion = [
      {
        assertion = (builtins.length hubPortsOnHost) == (builtins.length (lib.unique hubPortsOnHost));
        message = "Host '${hostName}' acts as a WireGuard hub on multiple active networks sharing the same UDP listen port.";
      }
    ];
  in
    membershipAssertions
    ++ ipValidAssertions
    ++ duplicateIpAssertions
    ++ hubExistenceAssertions
    ++ linkAssertions
    ++ gatewayAssertions
    ++ forwardAssertions
    ++ portCollisionAssertion;
}
