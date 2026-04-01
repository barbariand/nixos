{
  clusterMap, # { hostname = { id = "..."; ip = "10.55.0.x"; }; }
  syncedFolders,
  interface ? "wg0",
}: {
  lib,
  user,
  ...
}:
assert lib.asserts.assertMsg (builtins.isAttrs clusterMap) "clusterMap must be an attribute set.";
assert lib.asserts.assertMsg (lib.all (v: builtins.hasAttr "ip" v) (builtins.attrValues clusterMap))
"Every host in clusterMap must have an 'ip' defined for static peering.";
assert lib.asserts.assertMsg (builtins.isString user) "user must be a string."; let
  devices =
    lib.mapAttrs (name: cfg: {
      id = cfg.id;
      addresses = [
        "quic://${cfg.ip}:22000"
        "tcp://${cfg.ip}:22000"
      ];
    })
    clusterMap;
in {
  networking.firewall.interfaces.${interface} = {
    allowedTCPPorts = [22000 8384];
    allowedUDPPorts = [22000];
  };

  home-manager.users.${user}.services.syncthing = {
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

      folders =
        lib.mapAttrs (name: cfg: {
          label = name;
          id = cfg.id;
          path = cfg.path;
          fsWatcherEnabled = true;
          ignorePerms = true;
          type = "sendreceive";
          devices = builtins.attrNames devices;
        })
        syncedFolders;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/syncthing 774 ${user} users"
  ];
}
