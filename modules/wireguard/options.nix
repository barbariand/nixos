{
  lib,
  sensible_option,
  ...
}:
with lib; let
  stripFunctor = x: builtins.removeAttrs x ["__functor"];

  forwardType = types.coercedTo types.attrs stripFunctor (types.submodule {
    options = {
      port = mkOption {
        type = types.port;
        description = "Port on the hub's WireGuard address to listen on.";
      };
      targetNode = mkOption {
        type = types.str;
        description = "Destination node name in topology.nodes.";
      };
      targetPort = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Destination port on targetNode (defaults to 'port').";
      };
      targetNetwork = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "WireGuard network name of the target node if forwarding across two different WireGuard networks.";
      };
      protocol = mkOption {
        type = types.enum ["tcp" "udp"];
        default = "tcp";
      };
    };
  });
in
  sensible_option {
    wireguard = mkOption {
      default = {};
      description = "Declarative multi-network WireGuard topologies and nftables policies.";
      type = types.attrsOf (types.coercedTo types.attrs stripFunctor (types.submodule ({name, config, ...}: {
        options = {
          enable = mkEnableOption "this WireGuard network explicitly on this host";

          autoEnable = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically enable this network on any host present in topology.nodes.";
          };

          mode = mkOption {
            type = types.enum ["mesh" "gateway" "hub-only" "isolated"];
            default =
              if config.isolated
              then "isolated"
              else if config.interface != null
              then "gateway"
              else "mesh";
            defaultText = literalExpression ''if config.isolated then "isolated" else if config.interface != null then "gateway" else "mesh"'';
            description = ''
              Network security and routing profile:
              - "mesh": All peers can communicate with all peers and the hub (default).
              - "gateway": Full mesh plus NAT masquerading out through 'interface' on the hub.
              - "hub-only": Peers can communicate with the hub and forwarded services, but peer-to-peer traffic is blocked.
              - "isolated": Zero-trust network; all peer-to-peer and peer-to-hub traffic is dropped except explicit 'forwards' and 'firewall.allowed*Ports'.
            '';
          };

          isolated = mkOption {
            type = types.bool;
            default = false;
            description = "Shorthand to set mode = 'isolated', restricting peer-to-peer and peer-to-host access.";
          };

          privateKeyFile = mkOption {
            type = types.str;
            default = "/etc/wireguard/${name}.key";
            description = "Path to the host's private key file for this interface.";
          };

          interface = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "External/uplink network interface on the hub for WAN/LAN routing and masquerading (e.g. 'eth0').";
          };

          mtu = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Optional MTU override for the WireGuard netdev.";
          };

          forwards = mkOption {
            type = types.listOf forwardType;
            default = [];
            description = "Declarative DNAT/SNAT port forwards through the hub.";
          };

          firewall = {
            trustInterface = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Whether to add this interface to networking.firewall.trustedInterfaces (defaults to true for mesh/gateway, false for hub-only/isolated).";
            };

            allowPeerToPeer = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Whether the hub forwards traffic between peers on the same WireGuard network (defaults to true for mesh/gateway).";
            };

            allowExternalRouting = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Whether the hub routes and masquerades traffic out to 'interface' (defaults to true when interface != null in mesh/gateway mode).";
            };

            allowPing = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Whether to allow ICMP echo-requests on untrusted/isolated interfaces.";
            };

            allowedTCPPorts = mkOption {
              type = types.listOf types.port;
              default = [];
              description = "TCP ports to open on this WireGuard interface when trustInterface is false (e.g. [ 53 443 ] for split-horizon DNS and HTTPS).";
            };

            allowedUDPPorts = mkOption {
              type = types.listOf types.port;
              default = [];
              description = "UDP ports to open on this WireGuard interface when trustInterface is false (e.g. [ 53 ] for DNS).";
            };
          };

          nftables = {
            extraFilterRules = mkOption {
              type = types.lines;
              default = "";
              description = "Additional nftables rules appended to the forward chain before any isolation drop rule.";
            };

            extraInputRules = mkOption {
              type = types.lines;
              default = "";
              description = "Additional nftables rules appended to the input chain before any isolation drop rule.";
            };

            extraPreroutingRules = mkOption {
              type = types.lines;
              default = "";
              description = "Additional nftables rules appended to the prerouting NAT chain.";
            };

            extraPostroutingRules = mkOption {
              type = types.lines;
              default = "";
              description = "Additional nftables rules appended to the postrouting NAT chain.";
            };

            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Arbitrary extra chains or sets included inside the network's nftables table.";
            };
          };

          topology = {
            prefixLength = mkOption {
              type = types.ints.between 1 32;
              default = 24;
            };

            nodes = mkOption {
              default = {};
              type = types.attrsOf (types.submodule {
                options = {
                  publicKey = mkOption {type = types.str;};
                  ip = mkOption {type = types.str;};
                  extraAllowedIPs = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Additional CIDRs routed to this node.";
                  };
                };
              });
            };

            hubs = mkOption {
              default = {};
              type = types.attrsOf (types.submodule {
                options = {
                  endpoint = mkOption {type = types.str;};
                  port = mkOption {
                    type = types.port;
                    default = 51820;
                  };
                  persistentKeepalive = mkOption {
                    type = types.int;
                    default = 21;
                  };
                  links = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Explicit list of linked node names. If empty, links all other nodes in topology.nodes automatically.";
                  };
                  extraAllowedIPs = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Additional CIDRs advertised by this hub to connected clients.";
                  };
                };
              });
            };
          };
        };
      })));
    };
  }
