/*
# Utility to build a cluster of syncthing nodes isolated to a VPN
*/
{
  clusterMap, # { hostname = id; }
  syncedFolders,
  interface ? "wg0",
}: {
  lib,
  user,
  ...
}:
assert lib.asserts.assertMsg (builtins.isAttrs clusterMap) "clusterMap must be an attribute set.";
assert lib.asserts.assertMsg (builtins.isString user) "user must be a string."; {
  # Brandvägg isolerad till wireguard-interfacet
  networking.firewall.interfaces.${interface}.allowedTCPPorts = [22000 8384];
  home-manager.users.${user}.services.syncthing = {
    enable = true;

    overrideFolders = true;

    overrideDevices = true;
    inherit user;

    settings = rec {
      devices =
        clusterMap;

      folders =
        lib.mapAttrs (name: cfg: {
          label = cfg.label;
          id = cfg.id;
          path = cfg.path;

          fsWatcherEnabled = true;
          ignorePerms = true;
          type = "sendreceive";
          devices = builtins.attrNames devices;
        })
        folders;
    };
  };

  # Rättigheter för att tillåta synk av systemfiler

  systemd.tmpfiles.rules = ["d /var/lib/syncthing 774 root syncthing"];
}
