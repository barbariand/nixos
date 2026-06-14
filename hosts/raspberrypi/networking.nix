{config, ...}: {
  config.sensible.atlas = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = "192.168.1.3";

    internalNetworks = ["127.0.0.0/8" "192.168.1.0/24" "10.55.0.0/24"];

    dns.resolvers = ["1.1.1.1" "8.8.8.8"];

    dns.views = {
      wireguard = {
        accessControl = ["10.55.0.0/24"];
        localData = [
          "\"vault.simd.me. IN A 10.55.0.1\""
          "\"openclaw.simd.me. IN A 10.55.0.1\""
          "\"logs.simd.me. IN A 10.55.0.1\""
          "\"grafana.simd.me. IN A 10.55.0.1\""
          "\"homepage.simd.me. IN A 10.55.0.1\""
        ];
      };
    };

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
      wireguard = {
        enable = true;

        nginx.proxyPass = null;
      };
      vault = {
        enable = true;
        nginx.proxyPass = "http://127.0.0.1:8222";
      };

      dns = {
        enable = true;
        nginx.proxyPass = null;
      };

      mc = {
        enable = true;
        nginx.enable = false;
        streams.game = {
          port = 25566;
          protocol = "tcp";
          backend = "10.55.0.4:25566";
        };
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
            backend = "192.168.1.4:7777";
          };
          query = {
            port = 27015;
            protocol = "udp";
            backend = "192.168.1.4:27015";
          };
          raw = {
            port = 7778;
            protocol = "udp";
            backend = "192.168.1.4:7778";
          };
        };
      };

      openclaw = {
        enable = true;
        visibility = "internal";
        nginx.proxyPass = "http://10.55.0.2:9000";
      };

      logs = {
        enable = true;
        visibility = "internal";
        nginx.proxyPass = "http://127.0.0.1:3100";
      };
      grafana = {
        enable = true;
        visibility = "internal";
        nginx.proxyPass = "http://127.0.0.1:3000";
      };

      homepage = {
        enable = true;
        visibility = "internal";
        nginx.proxyPass = "http://127.0.0.1:8082";
      };
    };

    firewall = {
      allowedTCPPorts = [22];
      allowedUDPPorts = [51820];
    };
  };
}
