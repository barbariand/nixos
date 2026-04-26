/*
# Sensible Network Topology Utility (Subdomain Manager)
This module provides a declarative way to manage a complex web and DNS stack.
It automates the configuration of Nginx (Reverse Proxy), Unbound (DNS-over-TLS),
ACME (Wildcard Certificates via Let's Encrypt), and Cloudflare Dynamic DNS.

The goal is to provide a service-oriented architecture where you define what a
subdomain should *do*, and the module handles the underlying boilerplate and
service inter-dependencies.

## Parameters
| Name                 | Type    | Description                                                                 |
|----------------------|---------|-----------------------------------------------------------------------------|
| baseDomain           | string  | The root domain (e.g., "example.com"). No default; must be provided.        |
| serverIp             | string  | The target IPv4 address for all local A-records.                            |
| acme.enable          | bool    | Generates a wildcard certificate for the base domain and all subdomains.    |
| nginx.enable         | bool    | Manages Nginx virtualHosts, SSL redirection, and proxy settings.            |
| unbound.enable       | bool    | Manages a local Unbound recursive DNS server with DoT support.              |
| cloudflare.enable    | bool    | Syncs all enabled subdomains and the root domain to Cloudflare DNS.         |

## Usage
Import this module into your NixOS configuration and configure the `sensible.network` options.

### Example: Basic Vaultwarden & DNS Setup
```
{
  sensible.network = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = "192.168.1.3";

    acme = {
      enable = true;
      email = "admin@simd.me";
      credentialsFile = "/var/lib/acme/secrets/cloudflare-env";
    };

    nginx.enable = true;
    unbound.enable = true;
    cloudflare = {
      enable = true;
      tokenFile = "/etc/secrets/cloudflare-token";
    };

    subdomains = {
      vault = {
        enable = true;
        nginx.proxyPass = "http://127.0.0.1:8222";
      };
      dns = {
        enable = true;
        # Only DNS/DoT entry, no Nginx proxy needed
        nginx.enable = false;
      };
    };
  };
}
```
*/

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.sensible.network;

  # Submodule for individual subdomain configuration
  subdomainOpts = { name, ... }: {
    options = {
      enable = mkEnableOption "this subdomain";

      nginx = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to generate an Nginx virtualHost for this subdomain.";
        };
        proxyPass = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The upstream URI to proxy traffic to.";
        };
      };

      unbound = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to create a local A-record in Unbound.";
        };
      };

      cloudflare = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to sync this subdomain to Cloudflare DNS.";
        };
      };
    };
  };

in {
  options.sensible.network = {
    enable = mkEnableOption "Sensible Network Topology Manager";

    baseDomain = mkOption {
      type = types.str;
      example = "example.com";
      description = "The root domain name for the network stack.";
    };

    serverIp = mkOption {
      type = types.str;
      example = "192.168.1.10";
      description = "The IPv4 address used for generated A-records.";
    };

    # Service-specific isolated settings
    acme = {
      enable = mkEnableOption "Integrated Wildcard ACME management";
      email = mkOption { type = types.str; description = "Contact email for Let's Encrypt."; };
      credentialsFile = mkOption { type = types.path; description = "Environment file containing Cloudflare API tokens."; };
      dnsResolver = mkOption { type = types.str; default = "1.1.1.1:53"; description = "External DNS to use for ACME propagation checks."; };
    };

    nginx = {
      enable = mkEnableOption "Integrated Nginx Reverse Proxy management";
      defaultRootResponse = mkOption { type = types.str; default = "404"; description = "Nginx return code for the root domain if no location is defined."; };
    };

    unbound = {
      enable = mkEnableOption "Integrated Unbound DNS-over-TLS management";
      tlsPort = mkOption { type = types.port; default = 853; description = "The port Unbound will listen on for DoT."; };
    };

    cloudflare = {
      enable = mkEnableOption "Integrated Cloudflare Dynamic DNS management";
      tokenFile = mkOption { type = types.path; description = "File containing the Cloudflare API token for DDNS."; };
    };

    subdomains = mkOption {
      type = types.attrsOf (types.submodule subdomainOpts);
      default = { };
      description = "Attribute set of subdomains and their specific service requirements.";
    };
  };

  config = mkIf cfg.enable (mkMerge [

    # --- ACME Logic ---
    (mkIf cfg.acme.enable {
      security.acme = {
        acceptTerms = true;
        defaults = {
          inherit (cfg.acme) email credentialsFile dnsResolver;
          group = "nginx";
          dnsProvider = "cloudflare";
          webroot = null;
          # Automatically calculate which services to reload based on what is enabled
          reloadServices = (optional cfg.unbound.enable "unbound")
                        ++ (optional cfg.nginx.enable "nginx");
        };
        certs."${cfg.baseDomain}" = {
          domain = cfg.baseDomain;
          extraDomainNames = [ "*.${cfg.baseDomain}" ];
        };
      };
    })

    # --- Nginx Logic ---
    (mkIf cfg.nginx.enable {
      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        virtualHosts =
          let
            activeSubs = filterAttrs (n: s: s.enable && s.nginx.enable) cfg.subdomains;
            generated = mapAttrs' (name: sub: nameValuePair "${name}.${cfg.baseDomain}" {
              useACMEHost = mkIf cfg.acme.enable cfg.baseDomain;
              forceSSL = true;
              locations."/" = mkIf (sub.nginx.proxyPass != null) {
                proxyPass = sub.nginx.proxyPass;
                proxyWebsockets = true;
              };
            }) activeSubs;
          in
          {
            # Hardened root domain
            "${cfg.baseDomain}" = {
              useACMEHost = mkIf cfg.acme.enable cfg.baseDomain;
              forceSSL = true;
              locations."/".return = cfg.nginx.defaultRootResponse;
            };
          } // generated;
      };
    })

    # --- Unbound Logic ---
    (mkIf cfg.unbound.enable {
      services.unbound = {
        enable = true;
        settings.server = {
          interface = [ "0.0.0.0@${toString cfg.unbound.tlsPort}" "0.0.0.0@53" ];
          access-control = [ "127.0.0.0/8 allow" "192.168.1.0/24 allow" "10.55.0.0/24 allow" ];

          # Paths assume standard ACME module layout
          tls-service-key = "/var/lib/acme/${cfg.baseDomain}/key.pem";
          tls-service-pem = "/var/lib/acme/${cfg.baseDomain}/fullchain.pem";
          tls-port = cfg.unbound.tlsPort;

          local-zone = ''"${cfg.baseDomain}." static'';
          local-data =
            let
              activeSubs = filterAttrs (n: s: s.enable && s.unbound.enable) cfg.subdomains;
              mkRecord = name: ''"${name}.${cfg.baseDomain}. IN A ${cfg.serverIp}"'';
            in
            [ ''"${cfg.baseDomain}. IN A ${cfg.serverIp}"'' ]
            ++ (mapAttrsToList (n: v: mkRecord n) activeSubs);
        };
      };
      # Sandbox hole-punching for ACME certs
      systemd.services.unbound.serviceConfig.BindReadOnlyPaths = [ "/var/lib/acme/${cfg.baseDomain}" ];
      users.users.unbound.extraGroups = [ "acme" "nginx" ];
    })

    # --- Cloudflare Logic ---
    (mkIf cfg.cloudflare.enable {
      services.cloudflare-dyndns = {
        enable = true;
        apiTokenFile = cfg.cloudflare.tokenFile;
        domains =
          let
            activeSubs = filterAttrs (n: s: s.enable && s.cloudflare.enable) cfg.subdomains;
          in
          [ cfg.baseDomain ] ++ (mapAttrsToList (n: v: "${n}.${cfg.baseDomain}") activeSubs);
      };
    })
  ]);
}
