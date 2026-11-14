{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    ark-server = mkOption {
      default = {};
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible ARK: Survival Ascended Server";

          serverDir = mkOption {
            type = types.path;
            default = "/var/lib/ark-survival-ascended-server";
          };

          user = mkOption {
            type = types.str;
            default = "arkserver";
          };

          sessionName = mkOption {
            type = types.str;
            default = "NixOS ASA Server";
          };

          map = mkOption {
            type = types.str;
            default = "TheIsland_WP";
          };

          maxPlayers = mkOption {
            type = types.int;
            default = 70;
          };

          adminPasswordFile = mkOption {
            type = types.path;
            description = "Path to file containing the ARK ServerAdminPassword (e.g. via agenix).";
          };

          serverPasswordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Optional path to file containing the join ServerPassword.";
          };

          multiHome = mkOption {
            type = types.str;
            default = "";
            description = "IPv4 address to bind the server to.";
          };

          port = mkOption {
            type = types.port;
            default = 7777;
          };

          queryPort = mkOption {
            type = types.port;
            default = 27015;
          };

          rconPort = mkOption {
            type = types.port;
            default = 27020;
          };

          mods = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of CurseForge Mod IDs, e.g. [ \"952945\" ].";
          };

          publicDomain = mkOption {
            type = types.str;
            default = "";
            description = "DynDNS domain name dynamically resolved at startup to pass -PublicIP to Steamworks.";
          };

          autoUpdate = mkOption {
            type = types.bool;
            default = false;
            description = "Run steamcmd update on every service start.";
          };

          shutdownGracePeriodSec = mkOption {
            type = types.ints.positive;
            default = 30;
            description = "Seconds to wait after signaling shutdown for ArkAscendedServer.exe to persist save data before killing wineserver.";
          };

          shutdownCooldownSec = mkOption {
            type = types.ints.unsigned;
            default = 5;
            description = "Additional sleep duration (in seconds) after the main process exits before issuing wineserver -k and killing child processes.";
          };

          serviceConfig = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Extra systemd serviceConfig options merged directly into ark-survival-ascended-server.service.";
          };
        };
      };
    };
  }
