{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.ark-server;
  steamcmd_command = "${pkgs.steamcmd}/bin/steamcmd";
  xvfb_command = "${pkgs.xvfb-run}/bin/xvfb-run";
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

      systemd.services.ark-survival-ascended-updater = mkIf cfg.autoUpdate {
        description = "ARK: Survival Ascended Server Auto-Updater (SteamCMD)";
        after = ["network-online.target"];
        wants = ["network-online.target"];

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.user;
          WorkingDirectory = cfg.serverDir;
          TimeoutStartSec = 0;
          ExecStart = pkgs.writeShellScript "asa-steamcmd-update" ''
            ${steamcmd_command} \
              +force_install_dir "${cfg.serverDir}" \
              +login anonymous \
              +app_update 2430930 \
              +quit
          '';
        };
      };

      systemd.services.ark-survival-ascended-server = {
        description = "ARK: Survival Ascended Dedicated Server";
        after = ["network.target"] ++ optional cfg.autoUpdate "ark-survival-ascended-updater.service";
        wants = optional cfg.autoUpdate "ark-survival-ascended-updater.service";
        wantedBy = ["multi-user.target"];

        restartIfChanged = false;
        stopIfChanged = false;

        environment = {
          XDG_RUNTIME_DIR = "/run/ark-asa-server-runtime";
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };

        path = with pkgs; [
          coreutils
          iproute2
          nettools
          strace
          dnsutils
          procps
          cacert
        ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.user;

          RuntimeDirectory = "ark-asa-server-runtime";
          RuntimeDirectoryMode = "0700";

          WorkingDirectory = cfg.serverDir;
          TimeoutStartSec = 0;
          TimeoutStopSec = 300;
          StateDirectory = "ark-survival-ascended-server";
          LimitNOFILE = 1000000;

          ProtectProc = "default";
          ProcSubset = "all";
          PrivateNetwork = false;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
            "AF_PACKET"
            "AF_UNIX"
          ];
          CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];

          BindReadOnlyPaths = [
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/systemd/resolve"
          ];
          
          # Sends only SIGTERM to the bash script. This protects Xvfb and subprocesses
          # from being shut down abruptly by systemd before Wine is finished.
          KillMode = "mixed";

          ExecStartPre = pkgs.writeShellScript "asa-setup" ''
            touch "${cfg.serverDir}/.Xdefaults"
            echo "passwd: files" > "${cfg.serverDir}/nsswitch.conf"
            echo "group: files" >> "${cfg.serverDir}/nsswitch.conf"
            echo "hosts: files dns" >> "${cfg.serverDir}/nsswitch.conf"
            echo "networks: files" >> "${cfg.serverDir}/nsswitch.conf"
          '';

          ExecStart = pkgs.writeShellScript "asa-start" ''
            log() {
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] [asa-runner] $*"
            }

            export WINEPREFIX="${cfg.serverDir}/.wine"
            export WINEDEBUG="-all"
            export WINE_RESOLV_CONF="/etc/resolv.conf"
            export NSS_CONFIG_FILE="${cfg.serverDir}/nsswitch.conf"
            export GALLIUM_DRIVER="llvmpipe"
            export WINEDLLOVERRIDES="iphlpapi,ws2_32=b"

            cd "${cfg.serverDir}/ShooterGame/Binaries/Win64"

            MAP_ARGS="${cfg.map}?listen"
            MAP_ARGS="$MAP_ARGS?SessionName=${cfg.sessionName}"
            MAP_ARGS="$MAP_ARGS?MaxPlayers=${toString cfg.maxPlayers}"
            MAP_ARGS="$MAP_ARGS?Port=${toString cfg.port}"
            MAP_ARGS="$MAP_ARGS?QueryPort=${toString cfg.queryPort}"
            MAP_ARGS="$MAP_ARGS?RCONEnabled=True"
            MAP_ARGS="$MAP_ARGS?RCONPort=${toString cfg.rconPort}"
            MAP_ARGS="$MAP_ARGS?ServerAdminPassword=${cfg.adminPassword}"

            if [ -n "${cfg.serverPassword}" ]; then
              MAP_ARGS="$MAP_ARGS?ServerPassword=${cfg.serverPassword}"
            fi

            EXTRA_FLAGS=(
              "-server"
              "-log"
              "-servergamelog"
              "-crossplay"
              "-automanagedmods"
              "-NoRHI"
            )

            MODS_STRING="${concatStringsSep "," cfg.mods}"
            if [ -n "$MODS_STRING" ]; then
              EXTRA_FLAGS+=("-mods=$MODS_STRING")
            fi

            if [ -n "${cfg.multiHome}" ]; then
              EXTRA_FLAGS+=("-MultiHome=${cfg.multiHome}")
            fi

            if [ -n "${cfg.publicDomain}" ]; then
              PUBLIC_IP=$(${pkgs.dnsutils}/bin/dig +short "${cfg.publicDomain}" | tail -n1)
              if [ -n "$PUBLIC_IP" ]; then
                EXTRA_FLAGS+=("-PublicIP=$PUBLIC_IP")
              fi
            fi

            log "Initializing Wine prefix via wineboot..."
            ${pkgs.wine64}/bin/wineboot -u

            cleanup() {
              log "Received SIGTERM signal. Sending termination signal to steam-run (PID $SERVER_PID)..."
              if [ -n "$SERVER_PID" ]; then
                kill -TERM "$SERVER_PID" 2>/dev/null || true
                log "Waiting for the Ark process to save and shut down..."
                wait "$SERVER_PID" 2>/dev/null || true
              fi
            }
            # Catch both termination signals
            trap cleanup SIGTERM SIGINT

            log "Starting ArkAscendedServer.exe in the background..."
            ${pkgs.steam-run}/bin/steam-run ${xvfb_command} -a ${pkgs.wine64}/bin/wine ./ArkAscendedServer.exe "$MAP_ARGS" "''${EXTRA_FLAGS[@]}" &
            SERVER_PID=$!
            log "Main process started with PID: $SERVER_PID"

            wait "$SERVER_PID" || true
            log "ArkAscendedServer.exe has terminated."

            log "Killing wineserver inside steam-run (max 5s timeout)..."
            ${pkgs.coreutils}/bin/timeout 5 ${pkgs.steam-run}/bin/steam-run ${pkgs.wine64}/bin/wineserver -k || log "wineserver -k timed out or returned an error."

            log "Cleaning up any remaining child processes and Xvfb..."
            pkill -P $$ -9 2>/dev/null || true

            log "All processes cleaned up. Exiting the service cleanly."
          '';

          Restart = "on-failure";
          RestartSec = "30s";
        };
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
