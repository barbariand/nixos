{
  cfg,
  pkgs,
  lib,
  ...
}: let
  steamcmd_command = "${pkgs.steamcmd}/bin/steamcmd";
in {
  ark-survival-ascended-updater = lib.mkIf cfg.autoUpdate {
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
}
