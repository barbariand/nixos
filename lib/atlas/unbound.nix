{ config, lib, ... }:

with lib;

let
  cfg = config.sensible.atlas.unbound;
in {
  options.sensible.atlas.unbound = {
    enable = mkEnableOption "Atlas Unbound DNS";

    serverIp = mkOption { type = types.str; };
    baseDomain = mkOption { type = types.str; };
    resolvers = mkOption { type = types.listOf types.str; default = [ "1.1.1.1" ]; };

    localRecords = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Mapping of subdomain to IP.";
    };

    tls = {
      enable = mkEnableOption "DNS-over-TLS";
      certPath = mkOption { type = types.path; };
      keyPath = mkOption { type = types.path; };
    };
  };

  config = mkIf cfg.enable {
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = [ "0.0.0.0@853" "0.0.0.0@53" ];
          access-control = [ "127.0.0.0/8 allow" "192.168.1.0/24 allow" ];

          tls-port = mkIf cfg.tls.enable 853;
          tls-service-key = mkIf cfg.tls.enable "${cfg.tls.keyPath}";
          tls-service-pem = mkIf cfg.tls.enable "${cfg.tls.certPath}";

          local-zone = ''"${cfg.baseDomain}." static'';
          local-data = [ ''"${cfg.baseDomain}. IN A ${cfg.serverIp}"'' ]
            ++ (mapAttrsToList (n: ip: ''"${n}.${cfg.baseDomain}. IN A ${ip}"'') cfg.localRecords);
        };
        forward-zone = [{ name = "."; forward-addr = cfg.resolvers; }];
      };
    };

    # Brandvägg och rättigheter
    networking.firewall.allowedTCPPorts = [ 53 853 ];
    networking.firewall.allowedUDPPorts = [ 53 853 ];

    systemd.services.unbound.serviceConfig.BindReadOnlyPaths = mkIf cfg.tls.enable [ (builtins.dirOf cfg.tls.certPath) ];
  };
}
