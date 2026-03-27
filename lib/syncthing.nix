/*
# Utility to build a cluster of syncthing nodes isolated to a VPN
*/
{
  lib,
  clusterMap, # { hostname = { ip, id }; }
  user ? "cindy",
  syncPath ? "/etc/nixos",
  tunnel ? "wg0",
}:
assert lib.asserts.assertMsg (builtins.isAttrs clusterMap) "clusterMap must be an attribute set.";
assert lib.asserts.assertMsg (builtins.isString user) "user must be a string.";
assert lib.asserts.assertMsg (builtins.isString syncPath) "syncPath must be a path string."; let
  genNode = host: params: {
    services.syncthing = {
      enable = true;
      inherit user;
      dataDir = "/home/${user}/syncthing";
      guiAddress = "${params.ip}:8384";

      settings = {
        options = {
          listenAddresses = ["tcp://${params.ip}:22000"];
          localAnnounceEnabled = false;
          globalAnnounceEnabled = false;
          relaysEnabled = false;
        };

        # Definiera alla enheter i klustret
        devices =
          lib.mapAttrs (name: cfg: {
            id = cfg.id;
            addresses = ["tcp://${cfg.ip}:22000"];
          })
          clusterMap;

        # Konfigurera mappen som ska delas
        folders."nixos-config" = {
          path = syncPath;
          id = "nixos-cluster-config";
          # Dela med alla utom sig själv
          devices = builtins.attrNames (builtins.removeAttrs clusterMap [host]);
          versioning = {
            type = "simple";
            params.keep = "5";
          };
        };
      };
    };

    # Rättigheter för att tillåta synk av systemfiler
    systemd.tmpfiles.rules = [
      "d ${syncPath} 0775 root ${user} -"
    ];

    # Brandvägg isolerad till wireguard-interfacet
    networking.firewall.interfaces.${tunnel}.allowedTCPPorts = [22000 8384];
  };
in
  lib.mapAttrs (name: params: genNode name params) clusterMap
