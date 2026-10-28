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

      # Separat oneshot-service för uppdatering
      systemd.services.ark-server-update = mkIf cfg.autoUpdate {
        description = "ARK: Survival Ascended SteamCMD Updater";
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

      systemd.services.ark-server = {
        description = "ARK: Survival Ascended Server";
        after = ["network.target"] ++ optional cfg.autoUpdate "ark-server-update.service";
        wants = optional cfg.autoUpdate "ark-server-update.service";
        wantedBy = ["multi-user.target"];

        # Förhindra att nixos-rebuild switch hänger eller dödar servern vid deploy
        restartIfChanged = false;
        stopIfChanged = false;

        environment = {
          XDG_RUNTIME_DIR = "/run/ark-server-runtime";
        };

        path = with pkgs; [
          iproute2
          nettools
          strace
          dnsutils
        ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.user;

          RuntimeDirectory = "ark-server-runtime";
          RuntimeDirectoryMode = "0700";

          WorkingDirectory = cfg.serverDir;
          TimeoutStartSec = 0;
          StateDirectory = "ark-server";
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

          # Snabb pre-start för statiska filer (tar <10ms, blockerar inte deployment)
          ExecStartPre = pkgs.writeShellScript "asa-setup" ''
            touch "${cfg.serverDir}/.Xdefaults"
            echo "passwd: files" > "${cfg.serverDir}/nsswitch.conf"
            echo "group: files" >> "${cfg.serverDir}/nsswitch.conf"
            echo "hosts: files dns" >> "${cfg.serverDir}/nsswitch.conf"
            echo "networks: files" >> "${cfg.serverDir}/nsswitch.conf"
          '';

          ExecStart = pkgs.writeShellScript "asa-start" ''
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

            if [ -n "${cfg.mods}" ]; then
              MAP_ARGS="$MAP_ARGS?ModIds=${cfg.mods}"
            fi

            EXTRA_FLAGS=(
              "-server"
              "-log"
              "-servergamelog"
              "-crossplay"
              "-automanagedmods"
              "-NoRHI"
            )

            if [ -n "${cfg.multiHome}" ]; then
              EXTRA_FLAGS+=("-MultiHome=${cfg.multiHome}")
            fi

            if [ -n "${cfg.publicDomain}" ]; then
              PUBLIC_IP=$(${pkgs.dnsutils}/bin/dig +short "${cfg.publicDomain}" | tail -n1)
              if [ -n "$PUBLIC_IP" ]; then
                EXTRA_FLAGS+=("-PublicIP=$PUBLIC_IP")
              fi
            fi

            ${pkgs.wine64}/bin/wineboot -u

            exec ${pkgs.steam-run}/bin/steam-run ${xvfb_command} -a ${pkgs.wine64}/bin/wine ./ArkAscendedServer.exe "$MAP_ARGS" "''${EXTRA_FLAGS[@]}"
          '';

          Restart = "on-failure";
          RestartSec = "30s";
        };
      };

      environment.systemPackages = with pkgs; [
        steamcmd
        wine64
        xvfb-run
      ];
    };
  }
  |> sensibleLib.sensibleConfig
