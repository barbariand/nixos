{
  lib,
  sensible_option,
  ...
}:
with lib;
sensible_option {
  syncthing = mkOption {
    default = {};
    type = types.submodule {
      options = {
        enable = mkEnableOption "Sensible Syncthing";

        user = mkOption {
          type = types.str;
          description = "The OS user to run Syncthing under, and who will own the synced directories.";
        };

        cluster = mkOption {
          default = null;
          description = "The networking backend to use for dynamic IP resolution and firewall rules. Set to null for normal internet sync.";
          type = types.nullOr (types.submodule {
            options = {
              wireguard = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "The name of the wireguard interface (e.g., 'wg0') from config.sensible.wireguard.";
              };
            };
          });
        };

        nodes = mkOption {
          default = {};
          type = types.attrsOf (types.submodule {
            options = {
              id = mkOption { 
                type = types.str; 
                description = "Syncthing Device ID.";
              };
              addresses = mkOption { 
                type = types.listOf types.str; 
                default = []; 
                description = "Manual addresses, used independently of the cluster backend.";
              };
            };
          });
        };

        folders = mkOption {
          type = types.attrsOf types.attrs;
          default = {};
          description = "Configuration for Syncthing folders. Devices are auto-populated with all nodes if omitted. Defaults to sendreceive with fsWatcherEnabled.";
        };
      };
    };
  };
}
