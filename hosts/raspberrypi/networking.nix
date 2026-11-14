{
  config,
  sensibleLib,
  ...
}: let
  atlasLib = sensibleLib.atlas;
  wgLib = sensibleLib.wireguard;

  wg0 = config.sensible.wireguard.wg0;
  wg1 = config.sensible.wireguard.wg1;

  nodes = wg0.topology.nodes;
  piWgIp = nodes.raspberrypi.ip;
  homeIp = nodes.homecomputer.ip;
  serverOneIp = nodes.server_one.ip;
  buildServerIp = nodes.build_server.ip;
  lanIp = "192.168.1.3";
in {
  config.sensible.atlas = {
    enable = true;
    baseDomain = "simd.me";
    serverIp = lanIp;

    zones = {
      lan = {
        cidrs = [
          "127.0.0.0/8"
          "192.168.1.0/24"
        ];
        ip = lanIp;
        defaultInternal = true;
      };
      wireguard = {
        cidrs = [(wgLib.getNetworkCidr wg0)];
        ip = piWgIp;
        defaultInternal = true;
      };
      wg_ollama = {
        cidrs = [(wgLib.getNetworkCidr wg1)];
        ip = wg1.topology.nodes.raspberrypi.ip;
        defaultInternal = false;
      };
    };

    rules = {
      "*.internal" = {
        visibility = "internal";
        zones = [
          "lan"
          "wireguard"
        ];
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
      vault = atlasLib.mkPublic "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";

      cache = (atlasLib.mkPublic "http://${buildServerIp}:5000") {
        nginx.extraConfig = ''
          client_max_body_size 0;
          proxy_request_buffering off;
          proxy_buffering off;
        '';
      };

      wireguard = atlasLib.mkDnsOnly {unbound.enable = false;};
      dns = atlasLib.mkDnsOnly;

      ollama = atlasLib.mkZoneService ["wg_ollama" "wireguard" "lan"] "http://${homeIp}:11434";

      openclaw = atlasLib.mkInternal "http://${homeIp}:9000";
      logs = atlasLib.mkInternal "http://127.0.0.1:${toString config.sensible.loki.port}";
      grafana = atlasLib.mkInternal "http://127.0.0.1:${toString config.sensible.loki.grafanaPort}";
      homepage = atlasLib.mkInternal "http://127.0.0.1:${toString config.sensible.homepage.port}";

      mc = atlasLib.mkTcpStream 25566 "${serverOneIp}:25566";
      minecraft = atlasLib.mkTcpStream 25565 "${serverOneIp}:25565" {
        childNaming = "prefix";
        subdomains.ivar = atlasLib.mkTcpStream 25567 "${serverOneIp}:25567";
      };

      ai_research_buddy = atlasLib.mkPublic "http://${homeIp}:8855";
      ark = atlasLib.mkStreams {
        game = {
          port = 7777;
          protocol = "udp";
          backend = "${buildServerIp}:7777";
        };
        query = {
          port = 27015;
          protocol = "udp";
          backend = "${buildServerIp}:27015";
        };
        rcon = {
          port = 27020;
          protocol = "tcp";
          backend = "${buildServerIp}:27020";
        };
      };
    };

    firewall = {
      allowedTCPPorts = [22];
      allowedUDPPorts = [wg0.topology.hubs.raspberrypi.port];
    };
  };
}
