{ lib }:
with lib;
{
  # Subdomain-specific options
  subdomain = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Toggle this specific subdomain mapping.";
    };

    nginx = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Create an Nginx virtualHost for this subdomain.";
      };
      proxyPass = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "HTTP(S) upstream destination.";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Config placed inside the 'server' block.";
      };
    };

    unbound = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Create a local A-record for this subdomain.";
      };
    };

    cloudflare = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Include this subdomain in Dynamic DNS updates.";
      };
    };

    firewall = {
      allowedTCPPorts = mkOption {
        type = types.listOf types.port;
        default = [];
        description = "TCP ports to open for this specific subdomain.";
      };
      allowedUDPPorts = mkOption {
        type = types.listOf types.port;
        default = [];
        description = "UDP ports to open for this specific subdomain.";
      };
    };
  };

  # Global Service Options
  nginxGlobal = {
    defaultRootResponse = mkOption {
      type = types.str;
      default = "404";
      description = "Response code or action for the base domain root.";
    };
    appendConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Global Nginx configuration appended to the top-level context.";
    };
  };
}
