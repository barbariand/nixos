{
  lib,
  sensible_option,
  ...
}:
with lib; let
  vhostOpts = {name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      proxyPass = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Upstream URL (e.g. 'http://127.0.0.1:8080').";
      };
      websockets = mkOption {
        type = types.bool;
        default = true;
      };
      forceSSL = mkOption {
        type = types.bool;
        default = true;
      };
      acmeHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "ACME certificate name to use for this vHost.";
      };
      allowNetworks = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "If non-empty, restricts access to these CIDRs and denies all others.";
      };
      denyNetworks = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Explicit CIDRs to deny.";
      };
      extraHeaders = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Custom HTTP headers added via add_header.";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };
    };
  };

  streamOpts = {name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      port = mkOption {
        type = types.port;
      };
      protocol = mkOption {
        type = types.enum [
          "tcp"
          "udp"
        ];
        default = "tcp";
      };
      backend = mkOption {
        type = types.str;
        description = "Destination address:port (e.g. '10.55.0.4:25565').";
      };
      openFirewall = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };
in
  sensible_option {
    nginx = mkOption {
      default = {};
      description = "Declarative Nginx reverse proxy and L4 stream router.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible Nginx reverse proxy";

          acmeCert = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default ACME certificate name used by virtualHosts.";
          };

          defaultRootResponse = mkOption {
            type = types.str;
            default = "444";
            description = "Default response code for unknown Host headers.";
          };

          appendConfig = mkOption {
            type = types.lines;
            default = "";
          };

          openFirewall = mkOption {
            type = types.bool;
            default = true;
          };

          virtualHosts = mkOption {
            type = types.attrsOf (types.submodule vhostOpts);
            default = {};
          };

          streams = mkOption {
            type = types.attrsOf (types.submodule streamOpts);
            default = {};
          };
        };
      };
    };
  }
