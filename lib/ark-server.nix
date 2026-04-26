{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ark-server;
  # En hjälpare för att köra kommandon i Steams miljö
  steam-run_path = "${pkgs.steam-run}/bin/steam-run";
  steamcmd_path= "${pkgs.steamcmd}/bin/steamcmd";
in {
  options.services.ark-server = {
    enable = mkEnableOption "ARK Survival Evolved server";

    serverDir = mkOption {
      type = types.path;
      default = "/var/lib/ark-server";
      description = "Platsen där serverfilerna installeras. /var/lib är standard för tjänstedata.";
    };

    user = mkOption {
      type = types.str;
      default = "arkserver";
      description = "Systemanvändaren som kör tjänsten.";
    };

    # Serverinställningar
    sessionName = mkOption { type = types.str; default = "NixOS Ark Server"; };
    map = mkOption { type = types.str; default = "TheIsland"; };
    maxPlayers = mkOption { type = types.int; default = 70; };
    adminPassword = mkOption { type = types.str; default = "change-me-immediately"; };
    serverPassword = mkOption { type = types.str; default = ""; };

    # Portar
    port = mkOption { type = types.int; default = 7777; };
    queryPort = mkOption { type = types.int; default = 27015; };
    rconPort = mkOption { type = types.int; default = 27020; };

    mods = mkOption {
      type = types.str;
      default = "";
      description = "Kommaseparerad lista med Mod-IDs.";
    };
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      "fs.file-max" = 100000;
      "kernel.unprivileged_userns_clone" = 1; # Behövs ofta för Steam-miljön
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = cfg.serverDir;
      createHome = true;
      description = "ARK Server Daemon User";
    };
    users.groups.${cfg.user} = {};

    # 3. Brandvägg
    networking.firewall.allowedUDPPorts = [ cfg.port (cfg.port + 1) cfg.queryPort ];
    networking.firewall.allowedTCPPorts = [ cfg.rconPort ];

    # 4. Själva tjänsten
    systemd.services.ark-server = {
      description = "ARK Survival Evolved Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        WorkingDirectory = cfg.serverDir;

        TimeoutStartSec = 0;
        # Systemd hanterar mappen i /var/lib automatiskt
        StateDirectory = "ark-server";

        # Höjer gränsen för öppna filer specifikt för denna process
        LimitNOFILE = 1000000;

        # Uppdatera/Installera spelet innan start
        ExecStartPre = pkgs.writeShellScript "ark-update" ''
          export HOME=${cfg.serverDir}
          ${steam-run_path} ${steamcmd_path} \
            +force_install_dir "${cfg.serverDir}" \
            +login anonymous \
            +app_update 376030 validate \
            +quit
        '';

        # Starta servern
        ExecStart = pkgs.writeShellScript "ark-start" ''
          export HOME=${cfg.serverDir}
          cd "${cfg.serverDir}/ShooterGame/Binaries/Linux"

          # Bygg upp argumentsträngen
          ARGS="${cfg.map}?listen"
          ARGS="$ARGS?SessionName=${cfg.sessionName}"
          ARGS="$ARGS?MaxPlayers=${toString cfg.maxPlayers}"
          ARGS="$ARGS?Port=${toString cfg.port}"
          ARGS="$ARGS?QueryPort=${toString cfg.queryPort}"
          ARGS="$ARGS?ServerAdminPassword=${cfg.adminPassword}"

          if [ -n "${cfg.serverPassword}" ]; then
            ARGS="$ARGS?ServerPassword=${cfg.serverPassword}"
          fi

          if [ -n "${cfg.mods}" ]; then
            ARGS="$ARGS?ModIds=${cfg.mods}"
          fi

          ${steam-run_path} ./ShooterGameServer "$ARGS" \
            -server -log -servergamelog -crossplay -automanagedmods
        '';

        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    # Nödvändiga paket på systemnivå
    environment.systemPackages = with pkgs; [
      steamcmd
      steam-run
    ];
  };
}
