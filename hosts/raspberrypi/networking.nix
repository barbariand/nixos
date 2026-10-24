{
  config,
  sensibleLib,
  ...
}: let
  atlasLib = sensibleLib.atlas;
in {
  config.sensible.atlas = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = "192.168.1.3";

    zones = {
      lan = {
        cidrs = ["127.0.0.0/8" "192.168.1.0/24"];
        ip = "192.168.1.3";
        defaultInternal = true;
      };
      wireguard = {
        cidrs = ["10.55.0.0/24"];
        ip = "10.55.0.1";
        defaultInternal = true;
      };
      wg_ollama = {
        cidrs = ["10.56.0.0/24"];
        ip = "10.56.0.1";
        defaultInternal = false;
      };
    };

    rules = {
      "*.internal" = {
        visibility = "internal";
        zones = ["lan" "wireguard"];
      };
      "minecraft.*" = {
        visibility = "public";
        nginx.enable = false;
      };
    };

    acme = {
      enable = true;
      email = "cindy@simd.me";
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/acme/secrets/cloudflare-acme-env";
    };

    ddns = {
      enable = true;
      provider = "cloudflare";
      tokenFile = config.age.secrets.cloudflare-token.path;
    };

    subdomains = {
      vault = atlasLib.mkPublic "http://127.0.0.1:8222";

      cache = (atlasLib.mkPublic "http://10.55.0.5:5000") {
        nginx.extraConfig = ''
          client_max_body_size 0;
          proxy_request_buffering off;
          proxy_buffering off;
        '';
      };

      wireguard = atlasLib.mkDnsOnly;
      dns = atlasLib.mkDnsOnly;

      ollama = atlasLib.mkZoneService ["wg_ollama" "wireguard" "lan"] "http://10.55.0.2:11434";

      openclaw = atlasLib.mkInternal "http://10.55.0.2:9000";
      logs = atlasLib.mkInternal "http://127.0.0.1:3100";
      grafana = atlasLib.mkInternal "http://127.0.0.1:3000";
      homepage = atlasLib.mkInternal "http://127.0.0.1:8082";

      "ollama.internal".proxyPass = "http://10.55.0.2:11434";

      mc = atlasLib.mkTcpStream 25566 "10.55.0.4:25566";
      minecraft = atlasLib.mkTcpStream 25565 "10.55.0.4:25565" {
        childNaming = "prefix";
        subdomains.ivar = atlasLib.mkTcpStream 25567 "10.55.0.4:25567";
      };

      ark = atlasLib.mkStreams {
        game = {
          port = 7777;
          protocol = "udp";
          backend = "192.168.1.4:7777";
        };
        raw = {
          port = 7778;
          protocol = "udp";
          backend = "192.168.1.4:7778";
        };
        query = {
          port = 27015;
          protocol = "udp";
          backend = "192.168.1.4:27015";
        };
      };
    };

    firewall = {
      allowedTCPPorts = [22];
      allowedUDPPorts = [51820];
    };
  };
}
