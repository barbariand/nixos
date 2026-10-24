{
  lib,
  config,
  sensibleLib,
  ...
}: let
  hostName = config.networking.hostName;
  wgLib = import ../../lib/wireguard/default.nix {inherit lib;};

  allNetworks = config.sensible.wireguard;
  enabledNetworks = lib.filterAttrs (_: v: wgLib.isNetworkEnabled hostName v) allNetworks;
  activeNetworks = lib.filterAttrs (_: v: wgLib.isNetworkActive hostName v) allNetworks;

  nftablesNetworks = lib.filterAttrs (_: v: wgLib.needsNftables hostName v) activeNetworks;
  trustedNetworks = lib.filterAttrs (_: v: wgLib.trustInterface v) activeNetworks;
  untrustedNetworks = lib.filterAttrs (_: v: !(wgLib.trustInterface v)) activeNetworks;

  needsForwarding = lib.any (v: (wgLib.isRoutingHub hostName v) || (wgLib.isPolicyHub hostName v)) (lib.attrValues activeNetworks);
  needsNftables = nftablesNetworks != {};

  nftTables = lib.mapAttrs' (netName: netCfg:
    lib.nameValuePair "wg_${netName}" {
      family = "inet";
      content = wgLib.mkNetworkTable hostName netName netCfg allNetworks;
    }
  ) nftablesNetworks;

  perInterfaceFirewall = lib.mapAttrs (netName: netCfg: {
    allowedTCPPorts = lib.unique (
      (netCfg.firewall.allowedTCPPorts or [])
      ++ (wgLib.targetPortsForHostInNetwork "tcp" hostName netName netCfg allNetworks)
    );
    allowedUDPPorts = lib.unique (
      (netCfg.firewall.allowedUDPPorts or [])
      ++ (wgLib.targetPortsForHostInNetwork "udp" hostName netName netCfg allNetworks)
    );
  }) untrustedNetworks;

  mkSystemdPeers = netCfg:
    map (peer:
      {
        PublicKey = peer.publicKey;
        AllowedIPs = peer.allowedIPs;
      }
      // lib.optionalAttrs (peer ? endpoint && peer.endpoint != null) {
        Endpoint = peer.endpoint;
      }
      // lib.optionalAttrs (peer ? persistentKeepalive && peer.persistentKeepalive != null) {
        PersistentKeepalive = peer.persistentKeepalive;
      }
    ) (wgLib.resolvePeers hostName netCfg);

  mkNetdevs = lib.mapAttrs' (netName: netCfg: let
    isHub = wgLib.isHubNode hostName netCfg;
  in
    lib.nameValuePair "30-${netName}" ({
      netdevConfig = {
        Kind = "wireguard";
        Name = netName;
      } // lib.optionalAttrs (netCfg.mtu != null) {
        MTUBytes = toString netCfg.mtu;
      };
      wireguardConfig =
        {
          PrivateKeyFile = netCfg.privateKeyFile;
        }
        // lib.optionalAttrs isHub {
          ListenPort = netCfg.topology.hubs.${hostName}.port;
        };
      wireguardPeers = mkSystemdPeers netCfg;
    })
  ) activeNetworks;

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
  {
    condition = enabledNetworks != {};

    assertions = wgLib.mkAssertions hostName allNetworks;

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
          interfaces = perInterfaceFirewall;

          allowedUDPPorts = lib.mapAttrsToList
            (_: v: v.topology.hubs.${hostName}.port)
            (lib.filterAttrs (_: v: wgLib.isHubNode hostName v) activeNetworks);

          extraForwardRules = lib.mkIf needsNftables (wgLib.mkFirewallForwardRules hostName activeNetworks);
        };

        dhcpcd.denyInterfaces = builtins.attrNames activeNetworks;
        interfaces = lib.mapAttrs (_: _: {useDHCP = false;}) activeNetworks;

        nftables = lib.mkIf needsNftables {
          enable = true;
          tables = nftTables;
        };
      };
    };
  }
  |> sensibleLib.sensibleConfig
