{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    ddns = mkOption {
      default = {};
      description = "Pluggable Dynamic DNS (DDNS) updater supporting multiple providers.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible Dynamic DNS updater";

          provider = mkOption {
            type = types.enum [
              "cloudflare"
              "inadyn"
              "ddclient"
              "custom"
            ];
            default = "cloudflare";
            description = "DDNS backend implementation to use.";
          };

          domains = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of fully qualified domain names to keep updated.";
          };

          interval = mkOption {
            type = types.str;
            default = "5m";
            description = "Update check interval (used by timer/daemon backends).";
          };

          ipv4 = mkOption {
            type = types.bool;
            default = true;
          };

          ipv6 = mkOption {
            type = types.bool;
            default = false;
          };

          cloudflare = {
            tokenFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to file containing the Cloudflare API token.";
            };
            proxied = mkOption {
              type = types.bool;
              default = false;
              description = "Whether updated Cloudflare records should be orange-cloud proxied.";
            };
          };

          inadyn = {
            provider = mkOption {
              type = types.str;
              default = "cloudflare.com";
              description = "Inadyn provider identifier (e.g. 'cloudflare.com', 'duckdns.org', 'freedns.afraid.org').";
            };
            username = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Username or zone identifier for inadyn.";
            };
            passwordFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to secret file containing the password/token.";
            };
            extraSettings = mkOption {
              type = types.attrs;
              default = {};
            };
          };

          ddclient = {
            protocol = mkOption {
              type = types.str;
              default = "cloudflare";
              description = "ddclient protocol (e.g. 'cloudflare', 'porkbun', 'hetzner', 'dyndns2', 'namecheap').";
            };
            server = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            zone = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            username = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            passwordFile = mkOption {
              type = types.nullOr types.path;
              default = null;
            };
            extraConfig = mkOption {
              type = types.lines;
              default = "";
            };
          };

          custom = {
            script = mkOption {
              type = types.lines;
              default = "";
              description = "Custom shell script executed periodically to update DNS records.";
            };
            environmentFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Optional secret EnvironmentFile passed to the custom DDNS systemd service.";
            };
            packages = mkOption {
              type = types.listOf types.package;
              default = [];
              description = "Extra packages added to the custom DDNS service PATH.";
            };
          };
        };
      };
    };
  }
