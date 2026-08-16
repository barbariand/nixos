{
  config,
  lib,
  sensibleLib,
  ...
}:
with lib;
with sensibleLib; let
  cfg = config.sensible.syncthing;
  wgCfg = config.sensible.wireguard;

  isNone = cfg.cluster == null;
  isWireguard = !isNone && cfg.cluster.wireguard != null;
  
  # Import backend logic dynamically based on selection.
  # Fallback to an empty schema if no backend is selected.
  activeBackend = 
    if isWireguard then
      import ./wireguard.nix {
        inherit lib wgCfg;
        wgIf = cfg.cluster.wireguard;
      }
    else {
      resolveAddresses = nodeName: [];
      firewallInterface = null;
      assertions = [];
    };

  resolveAllAddresses = nodeName: nodeCfg:
    let
      explicitAddrs = nodeCfg.addresses;
      dynamicAddrs = activeBackend.resolveAddresses nodeName;
    in
      if dynamicAddrs != [] then explicitAddrs ++ dynamicAddrs else explicitAddrs;

  mappedDevices = mapAttrs (nodeName: nodeCfg: {
    id = nodeCfg.id;
    addresses = 
      let 
        addrs = resolveAllAddresses nodeName nodeCfg; 
      in
        if addrs == [] then [ "dynamic" ] else addrs;
  }) cfg.nodes;

  mappedFolders = mapAttrs (folderName: folderCfg: {
    label = folderName;
    id = folderCfg.id or folderName;
    path = folderCfg.path;
    type = folderCfg.type or "sendreceive";
    devices = folderCfg.devices or (builtins.attrNames cfg.nodes);
    fsWatcherEnabled = folderCfg.fsWatcherEnabled or true;
    ignorePerms = folderCfg.ignorePerms or true;
  } // folderCfg) cfg.folders;

in
  {
    condition = cfg.enable;

    assertions = activeBackend.assertions;

    system = {
      systemd.tmpfiles.rules = [
        "d /var/lib/syncthing 0774 ${cfg.user} users"
      ];

      networking.firewall.interfaces = mkIf (activeBackend.firewallInterface != null) {
        ${activeBackend.firewallInterface} = {
          allowedTCPPorts = [ 22000 8384 ]; 
          allowedUDPPorts = [ 22000 ];
          };
      };

      services.syncthing = {
        enable = true;
        user = cfg.user;
        dataDir = "/var/lib/syncthing";

        overrideDevices = true;
        overrideFolders = true;

        settings = {
          devices = mappedDevices;
          folders = mappedFolders;

          options = {
            globalAnnounceEnabled = isNone;
            localAnnounceEnabled = isNone;
            relaysEnabled = isNone;
            natEnabled = isNone;
            urAccepted = -1;
          };
        };
      };
    };
  } |> sensibleConfig
