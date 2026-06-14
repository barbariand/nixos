/*
# Sensible Atlas: The Declarative Ingress & DNS Manager
This module acts as a declarative map for your infrastructure.

## Global Options
| Option                                    | Type             | Description                                                                 |
|-------------------------------------------|------------------|-----------------------------------------------------------------------------|
| sensible.atlas.enable                     | bool             | Global toggle for the Atlas manager.                                        |
| sensible.atlas.baseDomain                 | string           | The root domain (e.g., "example.com"). No default.                          |
| sensible.atlas.serverIp                   | string           | Internal IPv4 for all generated A-records.                                  |
| sensible.atlas.internalNetworks           | list of str      | Trusted subnets for internal visibility (e.g., ["192.168.1.0/24"]).         |
| sensible.atlas.dns.resolvers              | list of str      | Upstream DNS servers for host and Unbound.                                  |
| sensible.atlas.firewall.extraTCPPorts     | list of int      | Any extra TCP ports to allow thourgh the firewall.                          |
| sensible.atlas.firewall.extraUDPPorts     | list of int      | Any extra UDP ports to allow thourgh the firewall.                          |

## Subdomain Options
Each attribute under `sensible.atlas.subdomains.<name>` supports:
| Option                           | Type          | Description                                                                    |
|----------------------------------|---------------|--------------------------------------------------------------------------------|
| enable                           | bool          | Toggle this specific subdomain.                                                |
| visibility                       | enum          | "public" (default) or "internal". Internal stops DDNS and restricts Nginx.     |
| nginx.enable                     | bool          | Toggle Nginx vHost creation (default: true).                                   |
| nginx.proxyPass                  | string/null   | Destination for proxying (e.g., "http://127.0.0.1:8000").                      |
| streams.<name>                   | attr set      | Define TCP/UDP streams (port, protocol, backend). Auto-opens firewall ports.   |

## Example Usage
<codeblock>
{
  sensible.atlas = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = "192.168.1.3";
    internalNetworks = [ "192.168.1.0/24" "10.55.0.0/24" "127.0.0.0/8" ];

    # ... enable flags for acme, unbound, cloudflare ...

    subdomains = {
      openclaw = {
        enable = true;
        visibility = "internal";
        nginx.proxyPass = "http://192.168.1.3:9000";
      };
      ark = {
        enable = true;
        nginx.enable = false;
        streams = {
          game  = { port = 7777; protocol = "udp"; backend = "192.168.1.2:7777"; };
          query = { port = 27015; protocol = "udp"; backend = "192.168.1.2:27015"; };
        };
      };
    };
  };
}
</codeblock>
*/
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  streamOpts = {name, ...}: {
    options = {
      port = mkOption {type = types.port;};
      protocol = mkOption {type = types.enum ["tcp" "udp"];};
      backend = mkOption {type = types.str;};
    };
  };

  subdomainOpts = {name, ...}: {
    options = {
      enable = mkEnableOption "this subdomain entry in Atlas";

      visibility = mkOption {
        type = types.enum ["public" "internal"];
        default = "public";
        description = "Set to internal to prevent DDNS updates and restrict Nginx access.";
      };

      nginx = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        proxyPass = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
        };
      };

      streams = mkOption {
        type = types.attrsOf (types.submodule streamOpts);
        default = {};
        description = "TCP/UDP stream configurations for this subdomain.";
      };

      unbound.enable = mkOption {
        type = types.bool;
        default = true;
      };
      cloudflare.enable = mkOption {
        type = types.bool;
        default = true;
      };

      firewall = {
        allowedTCPPorts = mkOption {
          type = types.listOf types.port;
          default = [];
        };
        allowedUDPPorts = mkOption {
          type = types.listOf types.port;
          default = [];
        };
      };
    };
  };
in {
  imports = [
    ./atlas/networking.nix
    ./atlas/acme.nix
    ./atlas/nginx.nix
    ./atlas/unbound.nix
    ./atlas/cloudflare.nix
  ];

  options.sensible.atlas = {
    enable = mkEnableOption "Sensible Atlas (Ingress & DNS Manager)";
    baseDomain = mkOption {type = types.str;};
    serverIp = mkOption {type = types.str;};

    internalNetworks = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of trusted CIDRs for internal subdomains.";
    };

    dns.resolvers = mkOption {
      type = types.listOf types.str;
      default = ["1.1.1.1" "8.8.8.8"];
    };

    dns.views = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          accessControl = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of network CIDRs mapping to this DNS view.";
          };
          localData = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Custom local-data lines overriding or defining records for this specific view.";
          };
        };
      });
      default = {};
      description = "Declarative Split-Horizon DNS views for specific subnets.";
    };

    acme = {
      enable = mkEnableOption "Atlas ACME Wildcard";
      email = mkOption {type = types.str;};
      environmentFile = mkOption {type = types.path;};
    };

    nginx = {
      enable = mkEnableOption "Atlas Nginx";
      defaultRootResponse = mkOption {
        type = types.str;
        default = "444";
      };
      appendConfig = mkOption {
        type = types.lines;
        default = "";
      };
    };

    unbound.enable = mkEnableOption "Atlas Unbound";

    cloudflare = {
      enable = mkEnableOption "Atlas Cloudflare DDNS";
      tokenFile = mkOption {type = types.path;};
    };

    subdomains = mkOption {
      type = types.attrsOf (types.submodule subdomainOpts);
      default = {};
    };

    firewall = {
      allowedTCPPorts = mkOption {
        type = types.listOf types.port;
        default = [];
      };
      allowedUDPPorts = mkOption {
        type = types.listOf types.port;
        default = [];
      };
    };
  };
}
