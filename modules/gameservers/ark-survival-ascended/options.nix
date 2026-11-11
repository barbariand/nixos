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

          adminPassword = mkOption {
            type = types.str;
            default = "change-me-immediately";
          };

          serverPassword = mkOption {
            type = types.str;
            default = "";
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
            description = "Lista över CurseForge Mod IDs, till exempel [ \"952945\" ].";
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

          priority = {
            cpuWeight = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
              description = "Systemd CPUWeight (1-10000) for cgroup CPU share prioritization.";
            };

            ioWeight = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
              description = "Systemd IOWeight (1-10000) for cgroup disk I/O prioritization.";
            };

            oomScoreAdjust = mkOption {
              type = types.nullOr (types.ints.between (-1000) 1000);
              default = null;
              description = "Systemd OOMScoreAdjust (-1000 to 1000). Negative values protect against OOM kills.";
            };

            nice = mkOption {
              type = types.nullOr (types.ints.between (-20) 19);
              default = null;
              description = "Process nice level (-20 to 19). Lower values yield higher CPU priority.";
            };
          };
        };
      };
    };
  }
