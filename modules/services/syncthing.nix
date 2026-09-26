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

  gitDefaultIgnores = [
    ".git/index.lock"
    ".git/objects/**"
    "target"
    "result"
    "result-*"
    ".direnv"
    "node_modules"
    "*.swp"
    "*~"
    ".stversions"
  ];

  mappedFolders = mapAttrs (folderName: folderCfg: {
    label = folderName;
    id = if folderCfg.id != null then folderCfg.id else folderName;
    path = folderCfg.path;
    type = folderCfg.type;
    devices = if folderCfg.devices != [] then folderCfg.devices else (builtins.attrNames cfg.nodes);
    fsWatcherEnabled = folderCfg.fsWatcherEnabled;
    fsWatcherDelayS = folderCfg.fsWatcherDelayS;
    ignorePerms = folderCfg.ignorePerms;
    ignorePatterns = folderCfg.ignorePatterns ++ (optional folderCfg.isGitRepo gitDefaultIgnores |> flatten);
  }) cfg.folders;

in
  {
    condition = cfg.enable;

    assertions = activeBackend.assertions;

    system = {
      # Inotify-höjning för att förhindra att Syncthing missar filändringar i djupa träd
      boot.kernel.sysctl = {
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 1024;
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/syncthing 0700 ${cfg.user} users"
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
        group = "users";
        dataDir = "/var/lib/syncthing";
        configDir = "/var/lib/syncthing/.config/syncthing";

        overrideDevices = true;
        overrideFolders = true;

        settings = {
          devices = mappedDevices;
          folders = mappedFolders;

          gui = {
            # Binder lokalt eller till WireGuard så att gränssnittet alltid är tillgängligt via tunneln
            address = if activeBackend.firewallInterface != null && builtins.hasAttr config.networking.hostName wgCfg.${activeBackend.firewallInterface}.topology.nodes
              then "${wgCfg.${activeBackend.firewallInterface}.topology.nodes.${config.networking.hostName}.ip}:8384"
              else "127.0.0.1:8384";
          };

          options = {
            globalAnnounceEnabled = isNone;
            localAnnounceEnabled = isNone;
            relaysEnabled = isNone;
            natEnabled = isNone;
            urAccepted = -1;
            # Pausar synk vid anslutningsavbrott istället för att logga timeouts
            setLowPriority = true;
          };
        };
      };
    };
  } |> sensibleConfig
