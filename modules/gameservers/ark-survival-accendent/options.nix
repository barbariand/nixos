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
            default = "/var/lib/ark-server";
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
            type = types.str;
            default = "";
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
        };
      };
    };
  }
