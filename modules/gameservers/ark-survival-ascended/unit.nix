{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.ark-server;

  updaterService = import ./updater.nix {inherit cfg pkgs lib;};
  serverService = import ./server.nix {inherit cfg pkgs lib;};
in
  {
    condition = cfg.enable;

    system = {
      boot.kernel.sysctl = {
        "fs.file-max" = 1000000;
        "vm.max_map_count" = 262144;
      };

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
        home = cfg.serverDir;
        createHome = true;
      };
      users.groups.${cfg.user} = {};

      networking.firewall.allowedUDPPorts = [
        cfg.port
        (cfg.port + 1)
        cfg.queryPort
      ];
      networking.firewall.allowedTCPPorts = [cfg.rconPort];

      networking.hosts = optionalAttrs (cfg.multiHome != "") {
        ${cfg.multiHome} = [config.networking.hostName];
      };

      systemd.services = {
        ark-survival-ascended-updater = updaterService.ark-survival-ascended-updater;
        ark-survival-ascended-server = serverService.ark-survival-ascended-server;
      };

      environment.systemPackages = with pkgs; [
        steamcmd
        wine64
        xvfb-run
        procps
        cacert
      ];
    };
  }
  |> sensibleLib.sensibleConfig
