{
  lib,
  sensible_option,
  ...
}:
with lib; let
  forwardType = types.coercedTo types.attrs (f: builtins.removeAttrs f ["__functor"]) (types.submodule {
    options = {
      port = mkOption {type = types.port;};
      targetNode = mkOption {type = types.str;};
      targetPort = mkOption {
        type = types.nullOr types.port;
        default = null;
      };
      targetNetwork = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Network interface of the target node if different from source network.";
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
      type = types.attrsOf (types.coercedTo types.attrs (n: builtins.removeAttrs n ["__functor"]) (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "this WireGuard network";

          isolated = mkOption {
            type = types.bool;
            default = false;
            description = "Restrict peer-to-peer and peer-to-host access, permitting only explicit forwards.";
          };

          privateKeyFile = mkOption {
            type = types.str;
            default = "/etc/wireguard/${name}.key";
          };

          interface = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          forwards = mkOption {
            type = types.listOf forwardType;
            default = [];
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
                  links = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };
                };
              });
            };
          };
        };
      })));
    };
  }
