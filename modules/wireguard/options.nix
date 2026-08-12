{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    wireguard = mkOption {
      default = {};
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          enable = mkEnableOption "";

          privateKeyFile = mkOption {
            type = types.str;
            default = "/etc/wireguard/${name}.key";
          };

          interface = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          topology = {
            prefixLength = mkOption { 
              type = types.ints.between 0 32; 
              default = 24; 
            };

            nodes = mkOption {
              default = {};
              type = types.attrsOf (types.submodule {
                options = {
                  publicKey = mkOption { type = types.str; };
                  ip = mkOption { type = types.str; };
                };
              });
            };

            hubs = mkOption {
              default = {};
              type = types.attrsOf (types.submodule {
                options = {
                  endpoint = mkOption { type = types.str; };
                  port = mkOption { type = types.port; default = 51820; };
                  links = mkOption { type = types.listOf types.str; default = []; };
                };
              });
            };
          };
        };
      }));
    };
  }
