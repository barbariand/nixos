{
  lib,
  sensible_option,
  ...
}:
with lib; let
  stripFunctor = x: builtins.removeAttrs x ["__functor"];

  streamOpts = {name, ...}: {
    options = {
      port = mkOption {type = types.port;};
      protocol = mkOption {
        type = types.enum ["tcp" "udp"];
        default = "tcp";
      };
      backend = mkOption {type = types.str;};
    };
  };

  zoneOpts = {name, ...}: {
    options = {
      cidrs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Network CIDRs belonging to this zone (e.g. ['10.55.0.0/24']).";
      };
      ip = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IPv4 address returned by Unbound Split-Horizon DNS for clients in this zone.";
      };
      defaultInternal = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If true, subdomains with visibility = "internal" automatically grant access to and
          inject DNS records into this zone unless the subdomain specifies an explicit 'zones' list.
          Set to false for isolated networks (such as guest/friend tunnels).
        '';
      };
      extraLocalData = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional raw Unbound local-data entries for this zone's DNS view.";
      };
    };
  };

  ruleOpts = {name, ...}: {
    options = {
      visibility = mkOption {
        type = types.nullOr (types.enum ["public" "internal"]);
        default = null;
      };
      zones = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Zones automatically assigned to matching subdomains.";
      };
      allowNetworks = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      denyNetworks = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      ddns.enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
      };
      unbound.enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
      };
      nginx = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
        extraHeaders = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
        };
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

  # Rekursiv subdomäntyp så att en subdomän kan definiera egna under-subdomäner
  subdomainType = types.coercedTo types.attrs stripFunctor (types.submodule ({name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this subdomain entry is enabled (defaults to true when declared).";
      };

      visibility = mkOption {
        type = types.nullOr (types.enum ["public" "internal"]);
        default = null;
        description = "Set to 'internal' to prevent DDNS updates and restrict Nginx access to allowed zones.";
      };

      proxyPass = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Shorthand for nginx.proxyPass.";
      };

      ip = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional custom IPv4 for Unbound base A-record (defaults to atlas.serverIp).";
      };

      zones = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Explicit list of zone names allowed to access and resolve this subdomain.";
      };

      allowNetworks = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional CIDRs permitted in Nginx for this subdomain.";
      };

      denyNetworks = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Explicit CIDRs denied in Nginx for this subdomain.";
      };

      childNaming = mkOption {
        type = types.enum ["subdomain" "prefix"];
        default = "subdomain";
        description = "How nested subdomains are joined ('subdomain' -> child.parent, 'prefix' -> parent.child).";
      };

      nginx = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
        proxyPass = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        websockets = mkOption {
          type = types.bool;
          default = true;
        };
        extraHeaders = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
        };
      };

      streams = mkOption {
        type = types.attrsOf (types.submodule streamOpts);
        default = {};
        description = "TCP/UDP L4 streams for this subdomain.";
      };

      unbound.enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
      };

      ddns.enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
      };

      cloudflare.enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Alias for ddns.enable.";
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

      subdomains = mkOption {
        type = types.attrsOf subdomainType;
        default = {};
        description = "Nested child subdomains inheriting this subdomain's policy.";
      };
    };
  }));
in
  sensible_option {
    atlas = mkOption {
      default = {};
      description = "Sensible Atlas: Declarative domain topology, zone policy, and service orchestrator.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible Atlas (Ingress, ACME, DDNS & Split-Horizon DNS Orchestrator)";

          baseDomain = mkOption {
            type = types.str;
            default = "";
            description = "Root domain name (e.g. 'simd.me').";
          };

          serverIp = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Default internal IPv4 address for Unbound A-records.";
          };

          zones = mkOption {
            type = types.attrsOf (types.submodule zoneOpts);
            default = {};
            description = "Named network zones defining CIDRs, Split-Horizon DNS IPs, and default internal trust.";
          };

          rules = mkOption {
            type = types.attrsOf (types.coercedTo types.attrs stripFunctor (types.submodule ruleOpts));
            default = {};
            description = "Wildcard/pattern rules (e.g. '*.internal', 'minecraft.*') applied across matching subdomains.";
          };

          subdomains = mkOption {
            type = types.attrsOf subdomainType;
            default = {};
            description = "Declarative subdomain definitions.";
          };

          internalNetworks = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional trusted CIDRs (supplementing 'zones').";
          };

          dns = {
            resolvers = mkOption {
              type = types.listOf types.str;
              default = ["1.1.1.1" "8.8.8.8"];
            };

            views = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  accessControl = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };
                  records = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                  };
                  localData = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };
                };
              });
              default = {};
              description = "Manual Split-Horizon DNS views (merged with views auto-generated from 'zones').";
            };
          };

          acme = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
            email = mkOption {
              type = types.str;
              default = "";
            };
            dnsProvider = mkOption {
              type = types.str;
              default = "cloudflare";
            };
            environmentFile = mkOption {
              type = types.nullOr types.path;
              default = null;
            };
          };

          ddns = {
            enable = mkOption {
              type = types.bool;
              default = false;
            };
            provider = mkOption {
              type = types.enum ["cloudflare" "inadyn" "ddclient" "custom"];
              default = "cloudflare";
            };
            tokenFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Token/password file passed to the selected DDNS provider.";
            };
          };

          # Bakåtkompatibel alias för ddns.provider = "cloudflare"
          cloudflare = {
            enable = mkEnableOption "Atlas Cloudflare DDNS (alias for sensible.atlas.ddns)";
            tokenFile = mkOption {
              type = types.nullOr types.path;
              default = null;
            };
          };

          nginx = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
            defaultRootResponse = mkOption {
              type = types.str;
              default = "444";
            };
            appendConfig = mkOption {
              type = types.lines;
              default = "";
            };
          };

          unbound = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
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
    };
  }
