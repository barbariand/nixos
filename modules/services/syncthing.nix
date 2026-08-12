{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.syncthing;

  devices = mapAttrs (name: hostCfg: {
    id = hostCfg.id;
    addresses = [
      "quic://${hostCfg.ip}:22000"
      "tcp://${hostCfg.ip}:22000"
    ];
  }) cfg.clusterMap;

in {
  options.sensible.syncthing = {
    enable = mkEnableOption "Sensible Syncthing";

    user = mkOption {
      type = types.str;
      description = "User to run syncthing under and own the directories.";
    };

    interface = mkOption {
      type = types.str;
      default = "wg0";
      description = "Interface to open the firewall ports on.";
    };

    clusterMap = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption { type = types.str; };
          ip = mkOption { type = types.str; };
        };
      });
      default = {};
      description = "Mapping of hostnames to their Syncthing IDs and IPs.";
    };

    syncedFolders = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption { type = types.str; };
          path = mkOption { type = types.str; };
        };
      });
      default = {};
      description = "Mapping of folder names to their IDs and absolute paths.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.interfaces.${cfg.interface} = {
      allowedTCPPorts = [22000 8384];
      allowedUDPPorts = [22000];
    };

    home-manager.users.${cfg.user}.services.syncthing = {
      enable = true;
      overrideFolders = true;
      overrideDevices = true;

      settings = {
        inherit devices;

        options = {
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          urAccepted = -1;
        };

        folders = mapAttrs (name: folderCfg: {
          label = name;
          id = folderCfg.id;
          path = folderCfg.path;
          fsWatcherEnabled = true;
          ignorePerms = true;
          type = "sendreceive";
          devices = attrNames devices;
        }) cfg.syncedFolders;
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/syncthing 774 ${cfg.user} users"
    ];
  };
}
