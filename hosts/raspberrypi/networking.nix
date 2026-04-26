{ config, pkgs, lib, ... }:

{
  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = "/etc/secrets/cloudflare-token";
    domains = ["minecraft.simd.me" "ark.simd.me" "simd.me" "dns.simd.me" ];
  };

services.resolved = lib.mkForce {
  enable = true;
  # Låt Pi:n använda Cloudflare internt om Unbound inte är uppe än
  fallbackDns = [ "1.1.1.1" ];
  };

  users.users.unbound.extraGroups = [ "acme" "nginx" ];
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "0.0.0.0@853" "0.0.0.0@53" ];
        access-control = [ "127.0.0.0/8 allow" "192.168.1.0/24 allow" "10.55.0.0/24 allow" ];

        # TLS-certifikat för DNS-over-TLS
        tls-service-key = "/var/lib/acme/simd.me/key.pem";
        tls-service-pem = "/var/lib/acme/simd.me/fullchain.pem";
        tls-port = 853;

        local-zone = ''"simd.me." static'';
        local-data = [
          ''"simd.me. IN A 192.168.1.3"''
          ''"dns.simd.me. IN A 192.168.1.3"''
          ''"vault.simd.me. IN A 192.168.1.3"''
          ''"minecraft.simd.me. IN A 192.168.1.3"''
        ];
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [ "1.1.1.1" "8.8.8.8" ];
        }
      ];
    };
  };
  systemd.services.unbound.serviceConfig = {
    # BindReadOnlyPaths tillåter Unbound att se in i ACME-mappen trots sandlådan
    BindReadOnlyPaths = [ "/var/lib/acme/simd.me" ];
    # Ibland behövs även detta om tjänsten körs med ProtectSystem=strict
    ReadWritePaths = [ "/var/lib/unbound" ];
  };
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."vault.simd.me" = {
      useACMEHost = "simd.me";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8222";
        proxyWebsockets = true;
      };
    };

    # För DNS-over-TLS certifikat
    virtualHosts."dns.simd.me" = {
      useACMEHost = "simd.me";
      forceSSL = true;
      # Ingen proxyPass behövs om Nginx bara används för ACME-utmaningen
    };

    appendConfig = ''
      stream {
        upstream minecraft_backend {
          server 10.55.0.4:25565;
        }
        server {
          listen 25565;
          proxy_pass minecraft_backend;
        }
        # ARK Game Port
        upstream ark_game_backend {
          server 192.168.1.2:7777;
        }
        server {
          listen 7777 udp;
          proxy_pass ark_game_backend;
        }

        # ARK Query Port
        upstream ark_query_backend {
          server 192.168.1.2:27015;
        }
        server {
          listen 27015 udp;
          proxy_pass ark_query_backend;
        }

        # Om du använder 7778 (Raw Sockets)
        upstream ark_raw_backend {
          server 192.168.1.2:7778;
        }
        server {
          listen 7778 udp;
          proxy_pass ark_raw_backend;
        }
      }
    '';
  };

security.acme = {
  acceptTerms = true;
  defaults = {
    group = "nginx";
    email = "cindy@simd.me";
    dnsProvider = "cloudflare";
    credentialsFile = "/var/lib/acme/secrets/cloudflare-acme-env";
    dnsResolver = "1.1.1.1:53";
    webroot = null;
    reloadServices = [ "unbound" "nginx" ];
  };

  certs."simd.me" = {
    domain = "simd.me";
    extraDomainNames = [ "*.simd.me" ];
  };
};
networking.nameservers = lib.mkForce [ "1.1.1.1" "8.8.8.8" ];
networking.firewall.allowedUDPPorts = [
  51820 53 853
  7777 7778 27015 # ARK Game & Query portar
];

networking.firewall.allowedTCPPorts = [
  53 80 443 25565 853
  22
];
}
