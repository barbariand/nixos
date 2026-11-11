{
  lib,
  sensible_option,
  ...
}:
with lib; let
  hostOpts = {name, ...}: {
    options = {
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target IP address or FQDN. Defaults to WireGuard IP if matching a WireGuard node, otherwise the attribute name.";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SSH login username (defaults to sensible.ssh-tools.defaultUser).";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Optional SSH port override.";
      };

      identityFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional path to a specific SSH private key.";
      };

      proxyJump = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional ProxyJump host alias or user@host specification.";
      };

      forwardAgent = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable SSH agent forwarding for this host.";
      };

      strictHostKeyChecking = mkOption {
        type = types.nullOr (types.enum [
          "yes"
          "no"
          "accept-new"
          "off"
        ]);
        default = null;
        description = "Optional StrictHostKeyChecking policy for this host.";
      };

      extraOptions = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional raw SSH client options for this MatchBlock.";
      };
    };
  };
in
  sensible_option {
    ssh-tools = mkOption {
      default = {};
      description = "Declarative SSH client matchBlocks, wrapper commands, and WireGuard topology integration.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible SSH Tools";

          defaultUser = mkOption {
            type = types.nullOr types.str;
            default = "cindy";
            description = "Default remote SSH username applied to WireGuard-derived and explicit hosts.";
          };

          generateWrapperScripts = mkOption {
            type = types.bool;
            default = true;
            description = "Generate 'ssh-<host>' convenience binaries in environment.systemPackages.";
          };

          wireguard = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Automatically derive SSH hosts from active networks in config.sensible.wireguard.";
            };

            interfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              example = ["wg0"];
              description = "Specific WireGuard interfaces to include (empty list includes all active networks on this host).";
            };

            ignorePeers = mkOption {
              type = types.listOf types.str;
              default = [];
              example = ["phone"];
              description = "Node names in WireGuard topology to exclude from SSH generation.";
            };

            perNetworkAliases = mkOption {
              type = types.bool;
              default = true;
              description = "Also generate '<netName>-<nodeName>' aliases in addition to bare '<nodeName>' aliases.";
            };
          };

          hosts = mkOption {
            type = types.attrsOf (types.submodule hostOpts);
            default = {};
            description = "Explicit SSH hosts or per-node overrides on top of WireGuard-derived nodes.";
          };
        };
      };
    };
  }
