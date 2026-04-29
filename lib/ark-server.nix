{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ark-server;
  steam-run_path = "${pkgs.steam-run}/bin/steam-run";
  steamcmd_path= "${pkgs.steamcmd}/bin/steamcmd";
in {
  options.services.ark-server = {
    enable = mkEnableOption "ARK Survival Evolved server";

    serverDir = mkOption {
      type = types.path;
      default = "/var/lib/ark-server";
      description = "Platsen där serverfilerna installeras.";
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
      "kernel.unprivileged_userns_clone" = 1;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = cfg.serverDir;
      createHome = true;
      description = "ARK Server Daemon User";
    };
    users.groups.${cfg.user} = {};

    networking.firewall.allowedUDPPorts = [ cfg.port (cfg.port + 1) cfg.queryPort ];
    networking.firewall.allowedTCPPorts = [ cfg.rconPort ];

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
        StateDirectory = "ark-server";
        LimitNOFILE = 1000000;

        # --- DEBUG-VÄNLIG UPDATE ---
        ExecStartPre = pkgs.writeShellScript "ark-update" ''
          set -x # Skriver ut varje kommando som körs till loggen
          export HOME=${cfg.serverDir}

          echo "--- STARTAR UPPDATERING ---"
          ${steam-run_path} ${steamcmd_path} \
            +force_install_dir "${cfg.serverDir}" \
            +login anonymous \
            +app_update 376030 validate \
            +quit

          echo "--- KONFIGURERAR STEAM-MILJÖ ---"
          mkdir -p $HOME/.steam/sdk64

          # Vi letar efter steamclient.so. ARK kan ibland flytta på den vid uppdateringar.
          # Vi försöker hitta den om den inte finns på standardplatsen.
          SRC_LIB="${cfg.serverDir}/Engine/Binaries/ThirdParty/Steamv132/Linux64/steamclient.so"

          if [ ! -f "$SRC_LIB" ]; then
            echo "VARNING: Kunde inte hitta steamclient.so på standardplatsen."
            echo "Söker efter filen i ${cfg.serverDir}..."
            SRC_LIB=$(find "${cfg.serverDir}" -name "steamclient.so" | head -n 1)
          fi

          if [ -n "$SRC_LIB" ] && [ -f "$SRC_LIB" ]; then
            echo "Länkar $SRC_LIB till förväntade sökvägar..."
            ln -sf "$SRC_LIB" $HOME/.steam/sdk64/steamclient.so
            ln -sf "$SRC_LIB" "${cfg.serverDir}/ShooterGame/Binaries/Linux/steamclient.so"
            ls -l $HOME/.steam/sdk64/steamclient.so
          else
            echo "FEL: steamclient.so kunde inte hittas någonstans!"
          fi

          echo "346110" > "${cfg.serverDir}/ShooterGame/Binaries/Linux/steam_appid.txt"
        '';

        # --- DEBUG-VÄNLIG START ---
        ExecStart = pkgs.writeShellScript "ark-start" ''
          set -x
          export HOME=${cfg.serverDir}
          export LD_LIBRARY_PATH="${cfg.serverDir}/ShooterGame/Binaries/Linux:$LD_LIBRARY_PATH"

          echo "--- KONTROLLERAR MILJÖ INNAN START ---"
          echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
          echo "Arbetskatalog: $(pwd)"
          ls -l ./steamclient.so || echo "Ingen steamclient.so i binärmappen"

          cd "${cfg.serverDir}/ShooterGame/Binaries/Linux"

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

          echo "Startar server med argument: $ARGS"

          exec ${steam-run_path} ./ShooterGameServer "$ARGS" \
            -server -log -servergamelog -crossplay -automanagedmods
        '';

        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    environment.systemPackages = with pkgs; [
      steamcmd
      steam-run
      file # Bra för att kolla binärtyper
      findutils # För 'find'-kommandot i debuggen
    ];
  };
}
