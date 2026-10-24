{
  lib,
  sensible_option,
  ...
}:
with lib;
sensible_option {
  k3s = mkOption {
    default = {};
    type = types.submodule {
      options = {
        enable = mkEnableOption "Sensible K3s Cluster";

        controllerNode = mkOption {
          type = types.str;
          default = "raspberrypi";
          description = "Hostname of the K3s server/controller node.";
        };

        controllerIp = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Explicit IPv4 of controller (resolved automatically if wireguardInterface is set).";
        };

        wireguardInterface = mkOption {
          type = types.nullOr types.str;
          default = "wg0";
          description = "WireGuard interface in sensible.wireguard used for node IP resolution and flannel binding.";
        };

        tokenFile = mkOption {
          type = types.path;
          description = "Path to K3s cluster secret token.";
        };

        controllerIsSchedulable = mkOption {
          type = types.bool;
          default = true;
        };

        controllerDisableTraefik = mkOption {
          type = types.bool;
          default = false;
        };

        nodes = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              ip = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              extraFlags = mkOption {
                type = types.str;
                default = "";
              };
            };
          });
          default = {};
          description = "Worker nodes in the cluster.";
        };

        globalExtraFlags = mkOption {
          type = types.str;
          default = "";
        };

        controllerExtraFlags = mkOption {
          type = types.str;
          default = "";
        };
      };
    };
  };
}
