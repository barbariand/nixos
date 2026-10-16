{
  lib,
  config,
  sensibleLib,
  ...
}: let
  hostName = config.networking.hostName;
  wgLib = import ../../lib/wireguard.nix {inherit lib;};

  enabledNetworks = lib.filterAttrs (_: v: v.enable) config.sensible.wireguard;
  activeNetworks = lib.filterAttrs (_: v: wgLib.isNodeInNetwork hostName v) enabledNetworks;

  routingNetworks = lib.filterAttrs (_: v: wgLib.isRoutingHub hostName v) activeNetworks;
  policyNetworks = lib.filterAttrs (_: v: wgLib.isPolicyHub hostName v) activeNetworks;
  trustedNetworks = lib.filterAttrs (_: v: !v.isolated) activeNetworks;

  needsForwarding = routingNetworks != {} || policyNetworks != {};

  routingTables = lib.mapAttrs' (netName: netCfg:
    lib.nameValuePair "wg_routing_${netName}" {
      family = "inet";
      content = wgLib.mkRoutingTable netName netCfg;
    }
  ) routingNetworks;

  policyTables = lib.mapAttrs' (netName: netCfg:
    lib.nameValuePair "wg_policy_${netName}" {
      family = "inet";
      content = wgLib.mkPolicyTable hostName netName netCfg enabledNetworks;
    }
  ) policyNetworks;

  isolatedTargetFirewall = lib.mapAttrs (_: netCfg: {
    allowedTCPPorts = wgLib.targetPortsForHost "tcp" hostName netCfg;
    allowedUDPPorts = wgLib.targetPortsForHost "udp" hostName netCfg;
  }) (lib.filterAttrs (_: v: v.isolated && wgLib.isForwardTarget hostName v) activeNetworks);
in
  sensibleLib.sensibleConfig {
    condition = enabledNetworks != {};

    assertions = wgLib.mkAssertions hostName enabledNetworks;

    system = lib.mkIf (activeNetworks != {}) {
      boot.kernel.sysctl = lib.mkIf needsForwarding {
        "net.ipv4.ip_forward" = true;
      };

      networking = {
        useNetworkd = true;

        firewall = {
          trustedInterfaces = builtins.attrNames trustedNetworks;
          interfaces = isolatedTargetFirewall;

          allowedUDPPorts = lib.mapAttrsToList
            (_: v: v.topology.hubs.${hostName}.port)
            (lib.filterAttrs (_: v: wgLib.isHubNode hostName v) activeNetworks);
        };

        dhcpcd.denyInterfaces = builtins.attrNames activeNetworks;
        interfaces = lib.mapAttrs (_: _: {useDHCP = false;}) activeNetworks;

        wireguard.interfaces = lib.mapAttrs (_: netCfg:
          wgLib.mkInterfaceConfig hostName netCfg
        ) activeNetworks;

        nftables = lib.mkIf needsForwarding {
          enable = true;
          tables = routingTables // policyTables;
        };
      };
    };
  }
