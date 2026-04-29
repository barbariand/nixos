/*
# Sensible Atlas: The Declarative Ingress & DNS Manager
This module acts as a "Map" for your infrastructure. It provides a service-oriented
way to define subdomains and automatically handles the heavy lifting for Nginx,
Unbound (DNS-over-TLS), ACME (Wildcard certs), and Cloudflare DDNS.

## Global Options
| Option                           | Type             | Description                                                                 |
|----------------------------------|------------------|-----------------------------------------------------------------------------|
| sensible.atlas.enable            | bool             | Global toggle for the Atlas manager.                                        |
| sensible.atlas.baseDomain        | string           | The root domain (e.g., "simd.me"). No default.                              |
| sensible.atlas.serverIp          | string           | Internal IPv4 for all generated A-records.                                  |
| sensible.atlas.dns.resolvers     | list of str      | Upstream DNS servers for host and Unbound (e.g., ["1.1.1.1"]).              |
| sensible.atlas.acme              | attribute set    | Configure wildcard cert generation. Needs email and credentialsFile.        |
| sensible.atlas.nginx             | attribute set    | Manages Reverse Proxy settings. Includes defaultRootResponse (default: 404).|
| sensible.atlas.unbound           | attribute set    | Manages local DNS-over-TLS on port 853.                                     |
| sensible.atlas.cloudflare        | attribute set    | Manages DDNS updates for root and subdomains. Needs tokenFile.              |
| sensible.atlas.subdomains.<name> | Submodule bellow | The custom config per domain                                                |
## Subdomain Options
Each attribute under `sensible.atlas.subdomains.<name>` supports:
| Option                           | Type          | Description                                                                    |
|----------------------------------|---------------|--------------------------------------------------------------------------------|
| enable                           | bool          | Toggle this specific subdomain.                                                |
| nginx.enable                     | bool          | Toggle Nginx vHost creation (default: true).                                   |
| nginx.proxyPass                  | string/null   | Destination for proxying (e.g., "http://127.0.0.1:8000").                      |
| nginx.extraConfig                | lines         | Raw Nginx config baked directly into the server block.                         |
| unbound.enable                   | bool          | Toggle local A-record creation (default: true).                                |
| cloudflare.enable                | bool          | Toggle Dynamic DNS update for this subdomain (default: true).                  |
| firewall.allowedTCPPorts         | list of port  | Specific TCP ports to open for this subdomain.                                 |
| firewall.allowedUDPPorts         | list of port  | Specific UDP ports to open for this subdomain.                                 |

## Example Usage
```
{
  sensible.atlas = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = "192.168.1.3";
    dns.resolvers = [ "1.1.1.1" "8.8.8.8" ];

    acme = {
      enable = true;
      email = "cindy@simd.me";
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
      minecraft = {
        enable = true;
        nginx.enable = false; # Handled by custom stream blocks
        firewall.allowedTCPPorts = [ 25565 ];
      };
    };
  };
}
```
*/

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.sensible.atlas;

  subdomainOpts = { name, ... }: {
    options = {
      enable = mkEnableOption "this subdomain entry in Atlas";

      nginx = {
        enable = mkOption { type = types.bool; default = true; };
        proxyPass = mkOption { type = types.nullOr types.str; default = null; };
        extraConfig = mkOption { type = types.lines; default = ""; };
      };

      unbound.enable = mkOption { type = types.bool; default = true; };
      cloudflare.enable = mkOption { type = types.bool; default = true; };

      firewall = {
        allowedTCPPorts = mkOption { type = types.listOf types.port; default = [ ]; };
        allowedUDPPorts = mkOption { type = types.listOf types.port; default = [ ]; };
      };
    };
  };

in {
  options.sensible.atlas = {
    enable = mkEnableOption "Sensible Atlas (Ingress & DNS Manager)";
    baseDomain = mkOption { type = types.str; description = "Root domain name."; };
    serverIp = mkOption { type = types.str; description = "Internal IPv4 address for DNS records."; };

    dns.resolvers = mkOption {
      type = types.listOf types.str;
      default = [ "1.1.1.1" "8.8.8.8" ];
    };

    acme = {
      enable = mkEnableOption "Atlas-integrated ACME Wildcard management";
      email = mkOption { type = types.str; };
      credentialsFile = mkOption { type = types.path; };
    };

    nginx = {
      enable = mkEnableOption "Atlas-integrated Nginx management";
      defaultRootResponse = mkOption { type = types.str; default = "404"; };
    };

    unbound.enable = mkEnableOption "Atlas-integrated Unbound DoT management";

    cloudflare = {
      enable = mkEnableOption "Atlas-integrated Cloudflare DDNS management";
      tokenFile = mkOption { type = types.path; };
    };

    subdomains = mkOption {
      type = types.attrsOf (types.submodule subdomainOpts);
      default = { };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # --- 1. Global Host Networking ---
    {
      networking.nameservers = lib.mkForce cfg.dns.resolvers;
      services.resolved = lib.mkForce {
        enable = true;
        fallbackDns = cfg.dns.resolvers;
      };

      # Automatically open ports defined in subdomains
      networking.firewall.allowedTCPPorts = flatten (mapAttrsToList (n: s: s.firewall.allowedTCPPorts) (filterAttrs (n: s: s.enable) cfg.subdomains));
      networking.firewall.allowedUDPPorts = flatten (mapAttrsToList (n: s: s.firewall.allowedUDPPorts) (filterAttrs (n: s: s.enable) cfg.subdomains));
    }

    # --- 2. ACME Service ---
    (mkIf cfg.acme.enable {
      security.acme = {
        acceptTerms = true;
        defaults = {
          inherit (cfg.acme) email credentialsFile;
          dnsResolver = head cfg.dns.resolvers;
          group = "nginx";
          dnsProvider = "cloudflare";
          webroot = null;
          reloadServices = (optional cfg.unbound.enable "unbound") ++ (optional cfg.nginx.enable "nginx");
        };
        certs."${cfg.baseDomain}" = {
          domain = cfg.baseDomain;
          extraDomainNames = [ "*.${cfg.baseDomain}" ];
        };
      };
    })

    # --- 3. Nginx Service ---
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
              extraConfig = sub.nginx.extraConfig;
              locations."/" = mkIf (sub.nginx.proxyPass != null) {
                proxyPass = sub.nginx.proxyPass;
                proxyWebsockets = true;
              };
            }) activeSubs;
          in
          {
            "${cfg.baseDomain}" = {
              useACMEHost = mkIf cfg.acme.enable cfg.baseDomain;
              forceSSL = true;
              locations."/".return = cfg.nginx.defaultRootResponse;
            };
          } // generated;
      };
      networking.firewall.allowedTCPPorts = [ 80 443 ];
    })

    # --- 4. Unbound Service ---
    (mkIf cfg.unbound.enable {
      services.unbound = {
        enable = true;
        settings = {
          server = {
            interface = [ "0.0.0.0@853" "0.0.0.0@53" ];
            access-control = [ "127.0.0.0/8 allow" "192.168.1.0/24 allow" "10.55.0.0/24 allow" ];
            tls-service-key = "/var/lib/acme/${cfg.baseDomain}/key.pem";
            tls-service-pem = "/var/lib/acme/${cfg.baseDomain}/fullchain.pem";
            tls-port = 853;
            local-zone = ''"${cfg.baseDomain}." static'';
            local-data =
              let
                activeSubs = filterAttrs (n: s: s.enable && s.unbound.enable) cfg.subdomains;
                mkRecord = name: ''"${name}.${cfg.baseDomain}. IN A ${cfg.serverIp}"'';
              in
              [ ''"${cfg.baseDomain}. IN A ${cfg.serverIp}"'' ] ++ (mapAttrsToList (n: v: mkRecord n) activeSubs);
          };
          forward-zone = [{
            name = ".";
            forward-addr = cfg.dns.resolvers;
          }];
        };
      };
      systemd.services.unbound.serviceConfig.BindReadOnlyPaths = [ "/var/lib/acme/${cfg.baseDomain}" ];
      users.users.unbound.extraGroups = [ "acme" "nginx" ];
      networking.firewall.allowedTCPPorts = [ 53 853 ];
      networking.firewall.allowedUDPPorts = [ 53 853 ];
    })

    # --- 5. Cloudflare DDNS ---
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
