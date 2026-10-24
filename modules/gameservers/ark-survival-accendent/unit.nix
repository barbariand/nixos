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

      networking.firewall.allowedUDPPorts = [cfg.port (cfg.port + 1) cfg.queryPort];
      networking.firewall.allowedTCPPorts = [cfg.rconPort];

      networking.hosts = optionalAttrs (cfg.multiHome != "") {
        ${cfg.multiHome} = [config.networking.hostName];
      };

      systemd.services.ark-server = {
        description = "ARK: Survival Ascended Server";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

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
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_NETLINK" "AF_PACKET" "AF_UNIX"];
          CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];

          BindReadOnlyPaths = [
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/systemd/resolve"
          ];

          ExecStartPre = pkgs.writeShellScript "asa-update" (
            ''
              touch "${cfg.serverDir}/.Xdefaults"
              echo "passwd: files" > "${cfg.serverDir}/nsswitch.conf"
              echo "group: files" >> "${cfg.serverDir}/nsswitch.conf"
              echo "hosts: files dns" >> "${cfg.serverDir}/nsswitch.conf"
              echo "networks: files" >> "${cfg.serverDir}/nsswitch.conf"
            ''
            + optionalString cfg.autoUpdate ''
              ${steamcmd_command} \
                +force_install_dir "${cfg.serverDir}" \
                +login anonymous \
                +app_update 2430930 \
                +quit
            ''
          );

          ExecStart = pkgs.writeShellScript "asa-start" ''
            export WINEPREFIX="${cfg.serverDir}/.wine"
            export WINEDEBUG="-all"
            export WINE_RESOLV_CONF="/etc/resolv.conf"
            export NSS_CONFIG_FILE="${cfg.serverDir}/nsswitch.conf"
            export GALLIUM_DRIVER="llvmpipe"
            export WINEDLLOVERRIDES="iphlpapi,ws2_32=b"

            cd "${cfg.serverDir}/ShooterGame/Binaries/Win64"

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

            EXTRA_FLAGS="-server -log -servergamelog -crossplay -automanagedmods -NoRHI"

            if [ -n "${cfg.multiHome}" ]; then
              EXTRA_FLAGS="$EXTRA_FLAGS -MultiHome=${cfg.multiHome}"
            fi

            if [ -n "${cfg.publicDomain}" ]; then
              PUBLIC_IP=$(${pkgs.dnsutils}/bin/dig +short "${cfg.publicDomain}" | tail -n1)
              if [ -n "$PUBLIC_IP" ]; then
                EXTRA_FLAGS="$EXTRA_FLAGS -PublicIP=$PUBLIC_IP"
              fi
            fi

            ${pkgs.wine64}/bin/wineboot -u

            exec ${pkgs.steam-run}/bin/steam-run ${xvfb_command} -a ${pkgs.wine64}/bin/wine ./ArkAscendedServer.exe "$ARGS" $EXTRA_FLAGS
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
