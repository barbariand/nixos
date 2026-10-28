{
  lib,
  sensible_option,
  ...
}:
with lib; let
  zoneOpts = {name, ...}: {
    options = {
      zoneType = mkOption {
        type = types.str;
        default = "transparent";
        description = "Unbound local-zone type (e.g. 'transparent', 'static', 'typetransparent').";
      };
      insecure = mkOption {
        type = types.bool;
        default = true;
        description = "Add domain to domain-insecure to allow internal non-DNSSEC records.";
      };
      records = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Mapping of FQDN to IPv4 address (automatically formatted into IN A local-data).";
      };
      rawLocalData = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional raw Unbound local-data lines.";
      };
    };
  };

  viewOpts = {name, ...}: {
    options = {
      accessControl = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "CIDRs mapped to this DNS view.";
      };
      zone = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Zone name for this view (e.g. 'simd.me').";
      };
      zoneType = mkOption {
        type = types.str;
        default = "transparent";
      };
      records = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Mapping of FQDN to IPv4 address for this view (no manual quoting required).";
      };
      localData = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Raw local-data strings for backward compatibility.";
      };
    };
  };
in
  sensible_option {
    unbound = mkOption {
      default = {};
      description = "Declarative Unbound DNS resolver with DoT and Split-Horizon views.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible Unbound DNS server";

          listenInterfaces = mkOption {
            type = types.listOf types.str;
            default = [
              "0.0.0.0@53"
              "0.0.0.0@853"
            ];
          };

          enableDoT = mkOption {
            type = types.bool;
            default = true;
            description = "Enable DNS-over-TLS on tlsPort.";
          };

          tlsPort = mkOption {
            type = types.port;
            default = 853;
          };

          acmeCert = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "ACME certificate name under /var/lib/acme/ used for DNS-over-TLS.";
          };

          resolvers = mkOption {
            type = types.listOf types.str;
            default = [
              "1.1.1.1"
              "8.8.8.8"
            ];
            description = "Upstream forward DNS resolvers.";
          };

          accessControl = mkOption {
            type = types.listOf types.str;
            default = [
              "127.0.0.0/8"
              "192.168.0.0/16"
              "10.0.0.0/8"
            ];
            description = "CIDRs allowed to query Unbound.";
          };

          zones = mkOption {
            type = types.attrsOf (types.submodule zoneOpts);
            default = {};
            description = "Authoritative/transparent local zones.";
          };

          views = mkOption {
            type = types.attrsOf (types.submodule viewOpts);
            default = {};
            description = "Split-Horizon DNS views.";
          };

          openFirewall = mkOption {
            type = types.bool;
            default = true;
          };
        };
      };
    };
  }
