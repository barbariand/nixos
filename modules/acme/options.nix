{
  lib,
  sensible_option,
  ...
}:
with lib; let
  certOpts = {name, ...}: {
    options = {
      domain = mkOption {
        type = types.str;
        default = name;
        description = "Primary domain name for this certificate.";
      };
      wildcard = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically include '*.<domain>' in extraDomainNames.";
      };
      extraDomainNames = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional SAN domains for this certificate.";
      };
      dnsProvider = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override global DNS provider for this certificate.";
      };
      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Override global credentials environmentFile for this certificate.";
      };
      webroot = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Webroot path if using HTTP-01 instead of DNS-01.";
      };
      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override group ownership for this certificate.";
      };
      reloadServices = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra systemd services to reload when this certificate is renewed.";
      };
    };
  };
in
  sensible_option {
    acme = mkOption {
      default = {};
      description = "Declarative ACME certificate management.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible ACME certificate management";

          email = mkOption {
            type = types.str;
            default = "";
            description = "Contact email address for Let's Encrypt account registration.";
          };

          acceptTerms = mkOption {
            type = types.bool;
            default = true;
          };

          dnsProvider = mkOption {
            type = types.nullOr types.str;
            default = "cloudflare";
            description = "Default Lego DNS-01 provider (e.g. 'cloudflare', 'hetzner', 'porkbun', 'route53', 'rfc2136').";
          };

          environmentFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the secret environment file for the DNS provider.";
          };

          dnsResolver = mkOption {
            type = types.str;
            default = "1.1.1.1:53";
            description = "DNS resolver used for DNS-01 propagation checks.";
          };

          group = mkOption {
            type = types.str;
            default = "acme";
            description = "Default UNIX group granted read access to issued certificates.";
          };

          reloadServices = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Systemd services reloaded whenever any certificate renews.";
          };

          certs = mkOption {
            type = types.attrsOf (types.submodule certOpts);
            default = {};
            description = "Certificate definitions keyed by certificate name.";
          };
        };
      };
    };
  }
