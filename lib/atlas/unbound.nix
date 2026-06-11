{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.atlas;
in {
  config = mkIf (cfg.enable && cfg.unbound.enable) {
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = ["0.0.0.0@853" "0.0.0.0@53"];
          access-control = ["127.0.0.0/8 allow" "192.168.1.0/24 allow" "10.55.0.0/24 allow"];

          tls-service-key = "/var/lib/acme/${cfg.baseDomain}/key.pem";
          tls-service-pem = "/var/lib/acme/${cfg.baseDomain}/fullchain.pem";
          tls-port = 853;

          local-zone = ''"${cfg.baseDomain}." transparent'';
          domain-insecure = ["${cfg.baseDomain}."];

          local-data = let
            activeSubs = filterAttrs (n: s: s.enable && s.unbound.enable) cfg.subdomains;
            mkRecord = name: ''"${name}.${cfg.baseDomain}. IN A ${cfg.serverIp}"'';
          in
            [''"${cfg.baseDomain}. IN A ${cfg.serverIp}"''] ++ (mapAttrsToList (n: v: mkRecord n) activeSubs);
        };
        forward-zone = [
          {
            name = ".";
            forward-addr = cfg.dns.resolvers;
          }
        ];
      };
    };

    systemd.services.unbound.serviceConfig = {
      BindReadOnlyPaths = ["/var/lib/acme/${cfg.baseDomain}"];
      ReadWritePaths = ["/var/lib/unbound"];
    };

    users.users.unbound.extraGroups = ["acme" "nginx"];
    networking.firewall.allowedTCPPorts = [53 853];
    networking.firewall.allowedUDPPorts = [53 853];
  };
}
