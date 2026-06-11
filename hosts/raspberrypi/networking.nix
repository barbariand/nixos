{
  config,
  pkgs,
  lib,
  ...
}: {
  config.sensible.atlas = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = "192.168.1.3";

    internalNetworks = ["127.0.0.0/8" "192.168.1.0/24" "10.55.0.0/24"];

    dns.resolvers = ["1.1.1.1" "8.8.8.8"];

    acme = {
      enable = true;
      email = "cindy@simd.me";
      environmentFile = "/var/lib/acme/secrets/cloudflare-acme-env";
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
        nginx.proxyPass = null;
      };

      minecraft = {
        enable = true;
        nginx.enable = false;
        streams.game = {
          port = 25565;
          protocol = "tcp";
          backend = "10.55.0.4:25565";
        };
      };

      ark = {
        enable = true;
        nginx.enable = false;
        streams = {
          game = {
            port = 7777;
            protocol = "udp";
            backend = "192.168.1.2:7777";
          };
          query = {
            port = 27015;
            protocol = "udp";
            backend = "192.168.1.2:27015";
          };
          raw = {
            port = 7778;
            protocol = "udp";
            backend = "192.168.1.2:7778";
          };
        };
      };

      openclaw = {
        enable = true;
        visibility = "internal";
        nginx.proxyPass = "http://192.168.1.3:9000";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [22];
  networking.firewall.allowedUDPPorts = [51820];
}
