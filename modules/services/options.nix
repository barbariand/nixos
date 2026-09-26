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
          description = "The OS user to run Syncthing under, matching local file ownership.";
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
          type = types.attrsOf (types.submodule {
            options = {
              id = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Folder ID in Syncthing (defaults to attribute name).";
              };
              path = mkOption {
                type = types.str;
                description = "Absolute path to the synced directory.";
              };
              type = mkOption {
                type = types.enum [ "sendreceive" "sendonly" "receiveonly" ];
                default = "sendreceive";
              };
              devices = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "List of node names to share this folder with. Defaults to all cluster nodes.";
              };
              ignorePerms = mkOption {
                type = types.bool;
                default = true;
                description = "Ignore file permissions (crucial for cross-system and git repos).";
              };
              fsWatcherEnabled = mkOption {
                type = types.bool;
                default = true;
                description = "Use inotify to monitor directory changes in real time.";
              };
              fsWatcherDelayS = mkOption {
                type = types.int;
                default = 10;
                description = "Delay before scanning after a batch of fs events (buffers rapid git writes).";
              };
              ignorePatterns = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Additional patterns to ignore inside this folder.";
              };
              isGitRepo = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to inject sensible ignore patterns for software development trees.";
              };
            };
          });
          default = {};
          description = "Declarative folder definitions with dev-friendly settings.";
        };
      };
    };
  };
}
