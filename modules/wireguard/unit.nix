{
  lib,
  config,
  sensibleLib,
  ...
}:
with sensibleLib; let
  hostName = config.networking.hostName;
  
  enabledNetworks = lib.filterAttrs (n: v: v.enable) config.sensible.wireguard;
  activeNetworks = lib.filterAttrs (n: v: builtins.hasAttr hostName v.topology.nodes) enabledNetworks;
  routingHubNetworks = lib.filterAttrs (n: v: builtins.hasAttr hostName v.topology.hubs && v.interface != null) activeNetworks;

  networkAssertions = lib.mapAttrsToList (netName: netCfg: {
    assertion = builtins.hasAttr hostName netCfg.topology.nodes;
    message = "Network '${netName}' is enabled, but host '${hostName}' is missing from the network topology nodes.";
  }) enabledNetworks;

in
  {
    condition = enabledNetworks != {};

    assertions = networkAssertions;

    system = lib.mkIf (activeNetworks != {}) {
      boot.kernel.sysctl = lib.mkIf (routingHubNetworks != {}) {
        "net.ipv4.ip_forward" = true;
      };

      networking = {
        useNetworkd = true;

        firewall.trustedInterfaces = builtins.attrNames activeNetworks;

        firewall.allowedUDPPorts = lib.mapAttrsToList 
          (n: v: v.topology.hubs.${hostName}.port) 
          (lib.filterAttrs (n: v: builtins.hasAttr hostName v.topology.hubs) activeNetworks);

        dhcpcd.denyInterfaces = builtins.attrNames activeNetworks;
        interfaces = lib.mapAttrs (n: v: { useDHCP = false; }) activeNetworks;

        wireguard = {
          interfaces = lib.mapAttrs (netName: netCfg: let
            nodes = netCfg.topology.nodes;
            localNode = nodes.${hostName};
            
            isHub = builtins.hasAttr hostName netCfg.topology.hubs;
            localHubCfg = netCfg.topology.hubs.${hostName} or null;

            uplinkHubs = lib.filterAttrs (hName: hCfg: builtins.elem hostName hCfg.links) netCfg.topology.hubs;

            hubPeers = lib.optionalAttrs isHub (
              lib.genAttrs localHubCfg.links (linkName: let
                linkNode = nodes.${linkName};
              in {
                publicKey = linkNode.publicKey;
                allowedIPs = [ "${linkNode.ip}/32" ];
              })
            );

            clientPeers = lib.mapAttrs (hName: hCfg: let
                hubNode = nodes.${hName};
              in {
                publicKey = hubNode.publicKey;
                endpoint = "${hCfg.endpoint}:${builtins.toString hCfg.port}";
                # Note: systemd-networkd strictly requires host bits to be zeroed in subnet addresses.
                allowedIPs = [ "${hubNode.ip}/${builtins.toString netCfg.topology.prefixLength}" ];
                persistentKeepalive = 21;
            }) uplinkHubs;

            # Note: Merge resolution favors clientPeers. Keys must be unique across hub and client definitions to avoid overwriting asymmetrical links.
            allPeers = hubPeers // clientPeers;
          in {
            listenPort = if isHub then localHubCfg.port else null;
            privateKeyFile = netCfg.privateKeyFile;
            ips = [ "${localNode.ip}/${builtins.toString netCfg.topology.prefixLength}" ];
            peers = lib.attrValues allPeers;
          }) activeNetworks;
        };

        nftables = lib.mkIf (routingHubNetworks != {}) {
          enable = true;
          flushRuleset = true;
          ruleset = lib.concatStringsSep "\n" (lib.mapAttrsToList (netName: netCfg: ''
            table inet filter_${netName} {
              chain forward {
                type filter hook forward priority filter; policy accept;
                ct state established,related accept
                iifname "${netName}" oifname "${netCfg.interface}" counter accept
                iifname "${netName}" oifname "${netName}" counter accept
              }
            }
            table inet nat_${netName} {
              chain postrouting {
                type nat hook postrouting priority srcnat;
                oifname "${netCfg.interface}" counter masquerade
              }
            }
          '') routingHubNetworks);
        };
      };
    };
  } |> sensibleConfig
