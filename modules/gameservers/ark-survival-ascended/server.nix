{
  cfg,
  pkgs,
  lib,
  ...
}: let
  xvfb_command = "${pkgs.xvfb-run}/bin/xvfb-run";
in {
  ark-survival-ascended-server = {
    description = "ARK: Survival Ascended Dedicated Server";
    after = ["network.target"] ++ lib.optional cfg.autoUpdate "ark-survival-ascended-updater.service";
    wants = lib.optional cfg.autoUpdate "ark-survival-ascended-updater.service";
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

    serviceConfig =
      lib.recursiveUpdate {
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
          export WINE_DISABLE_MESSAGE_BOXES=1

          cd "${cfg.serverDir}/ShooterGame/Binaries/Win64"

          ADMIN_PASS=$(cat "${toString cfg.adminPasswordFile}")

          MAP_ARGS="${cfg.map}?listen"
          MAP_ARGS="$MAP_ARGS?SessionName=${cfg.sessionName}"
          MAP_ARGS="$MAP_ARGS?MaxPlayers=${toString cfg.maxPlayers}"
          MAP_ARGS="$MAP_ARGS?Port=${toString cfg.port}"
          MAP_ARGS="$MAP_ARGS?QueryPort=${toString cfg.queryPort}"
          MAP_ARGS="$MAP_ARGS?RCONEnabled=True"
          MAP_ARGS="$MAP_ARGS?RCONPort=${toString cfg.rconPort}"
          MAP_ARGS="$MAP_ARGS?ServerAdminPassword=$ADMIN_PASS"

          ${lib.optionalString (cfg.serverPasswordFile != null) ''
            SERVER_PASS=$(cat "${toString cfg.serverPasswordFile}")
            if [ -n "$SERVER_PASS" ]; then
              MAP_ARGS="$MAP_ARGS?ServerPassword=$SERVER_PASS"
            fi
          ''}

          EXTRA_FLAGS=(
            "-server"
            "-log"
            "-servergamelog"
            "-automanagedmods"
            "-NoRHI"
          )

          MODS_STRING="${lib.concatStringsSep "," cfg.mods}"
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
            log "Received shutdown signal. Notifying Ark process and waiting for clean persistence..."

            ARK_PID=$(pgrep -f "ArkAscendedServer.exe" | head -n 1 || true)
            if [ -n "$ARK_PID" ]; then
              log "Signaling ArkAscendedServer.exe (PID $ARK_PID) directly..."
              kill -TERM "$ARK_PID" 2>/dev/null || true
            fi

            if [ -n "$SERVER_PID" ]; then
              kill -TERM "$SERVER_PID" 2>/dev/null || true
            fi

            WAIT_LIMIT=${toString cfg.shutdownGracePeriodSec}
            ELAPSED=0
            while pgrep -f "ArkAscendedServer.exe" >/dev/null 2>&1; do
              if [ "$ELAPSED" -ge "$WAIT_LIMIT" ]; then
                log "Timeout ($WAIT_LIMIT s) reached while waiting for Ark to shut down cleanly."
                break
              fi
              sleep 1
              ELAPSED=$((ELAPSED + 1))
            done

            if [ -n "$SERVER_PID" ]; then
              wait "$SERVER_PID" 2>/dev/null || true
            fi

            COOLDOWN=${toString cfg.shutdownCooldownSec}
            if [ "$COOLDOWN" -gt 0 ]; then
              log "Entering shutdown cooldown of $COOLDOWN seconds before tearing down Wine..."
              sleep "$COOLDOWN"
            fi
          }
          trap cleanup SIGTERM SIGINT

          log "Starting ArkAscendedServer.exe in the background..."
          ${pkgs.steam-run}/bin/steam-run ${xvfb_command} -a ${pkgs.wine64}/bin/wine ./ArkAscendedServer.exe "$MAP_ARGS" "''${EXTRA_FLAGS[@]}" &
          SERVER_PID=$!
          log "Main process started with PID: $SERVER_PID"

          wait "$SERVER_PID" || true
          log "ArkAscendedServer.exe has terminated."

          COOLDOWN=${toString cfg.shutdownCooldownSec}
          if [ "$COOLDOWN" -gt 0 ]; then
            sleep "$COOLDOWN"
          fi

          log "Killing wineserver inside steam-run (max 5s timeout)..."
          ${pkgs.coreutils}/bin/timeout 5 ${pkgs.steam-run}/bin/steam-run ${pkgs.wine64}/bin/wineserver -k || log "wineserver -k timed out or returned an error."

          log "Cleaning up any remaining child processes and Xvfb..."
          pkill -P $$ -9 2>/dev/null || true

          log "All processes cleaned up. Exiting the service cleanly."
        '';

        Restart = "on-failure";
        RestartSec = "30s";
      }
      cfg.serviceConfig;
  };
}
