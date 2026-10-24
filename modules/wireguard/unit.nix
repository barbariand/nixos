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

  # Omvandlar peer-listan från wgLib till modern systemd-networkd wireguardPeers-syntax
  mkSystemdPeers = netCfg:
    map (peer: {
      PublicKey = peer.publicKey;
      AllowedIPs = peer.allowedIPs;
    } // lib.optionalAttrs (peer ? endpoint && peer.endpoint != null) {
      Endpoint = peer.endpoint;
    } // lib.optionalAttrs (peer ? persistentKeepalive && peer.persistentKeepalive != null) {
      PersistentKeepalive = peer.persistentKeepalive;
    }) (wgLib.resolvePeers hostName netCfg);

  # Generera .netdev-konfiguration för varje aktivt gränssnitt
  mkNetdevs = lib.mapAttrs' (netName: netCfg: let
    isHub = wgLib.isHubNode hostName netCfg;
  in
    lib.nameValuePair "30-${netName}" {
      netdevConfig = {
        Kind = "wireguard";
        Name = netName;
      };
      wireguardConfig = {
        PrivateKeyFile = netCfg.privateKeyFile;
      } // lib.optionalAttrs isHub {
        ListenPort = netCfg.topology.hubs.${hostName}.port;
      };
      wireguardPeers = mkSystemdPeers netCfg;
    }
  ) activeNetworks;

  # Generera .network-konfiguration för varje aktivt gränssnitt
  mkNetworks = lib.mapAttrs' (netName: netCfg: let
    localNode = netCfg.topology.nodes.${hostName};
  in
    lib.nameValuePair "30-${netName}" {
      matchConfig.Name = netName;
      networkConfig = {
        Address = "${localNode.ip}/${toString netCfg.topology.prefixLength}";
      };
    }
  ) activeNetworks;
in
  sensibleLib.sensibleConfig {
    condition = enabledNetworks != {};

    assertions = wgLib.mkAssertions hostName enabledNetworks;

    system = lib.mkIf (activeNetworks != {}) {
      boot.kernel.sysctl = lib.mkIf needsForwarding {
        "net.ipv4.ip_forward" = true;
      };

      systemd.network = {
        enable = true;
        netdevs = mkNetdevs;
        networks = mkNetworks;
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

        nftables = lib.mkIf needsForwarding {
          enable = true;
          tables = routingTables // policyTables;
        };
      };
    };
  }
