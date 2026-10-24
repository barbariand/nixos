{
  config,
  lib,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.atlas;
  atlasLib = import ../../lib/atlas {inherit lib;};

  activeSubs = atlasLib.resolveAllSubdomains cfg;
  ddnsEnabled = cfg.ddns.enable || cfg.cloudflare.enable;
  ddnsTokenFile = if cfg.ddns.tokenFile != null then cfg.ddns.tokenFile else cfg.cloudflare.tokenFile;
  extraFw = atlasLib.resolveExtraFirewall cfg activeSubs;
in
  {
    condition = cfg.enable;

    assertions = atlasLib.mkAssertions cfg;

    system = {
      sensible = {
        acme = mkIf cfg.acme.enable {
          enable = true;
          email = mkDefault cfg.acme.email;
          dnsProvider = mkDefault cfg.acme.dnsProvider;
          environmentFile = mkDefault cfg.acme.environmentFile;
          dnsResolver = mkDefault "${head cfg.dns.resolvers}:53";
          group = mkDefault "nginx";
          reloadServices =
            (optional cfg.unbound.enable "unbound")
            ++ (optional cfg.nginx.enable "nginx");
          certs.${cfg.baseDomain} = {
            domain = cfg.baseDomain;
            wildcard = true;
          };
        };

        ddns = mkIf ddnsEnabled {
          enable = true;
          provider = mkDefault cfg.ddns.provider;
          domains = atlasLib.resolveDdnsDomains cfg activeSubs;
          cloudflare.tokenFile = mkIf (ddnsTokenFile != null) (mkDefault ddnsTokenFile);
          inadyn.passwordFile = mkIf (ddnsTokenFile != null) (mkDefault ddnsTokenFile);
          ddclient.passwordFile = mkIf (ddnsTokenFile != null) (mkDefault ddnsTokenFile);
        };

        unbound = mkIf cfg.unbound.enable {
          enable = true;
          acmeCert = mkDefault (if cfg.acme.enable then cfg.baseDomain else null);
          resolvers = mkDefault cfg.dns.resolvers;
          accessControl = atlasLib.resolveUnboundAccessControl cfg;
          zones.${cfg.baseDomain} = {
            zoneType = "transparent";
            insecure = true;
            records = atlasLib.resolveUnboundBaseRecords cfg activeSubs;
          };
          views = atlasLib.resolveUnboundViews cfg activeSubs;
        };

        nginx = mkIf cfg.nginx.enable {
          enable = true;
          acmeCert = mkDefault (if cfg.acme.enable then cfg.baseDomain else null);
          defaultRootResponse = mkDefault cfg.nginx.defaultRootResponse;
          appendConfig = cfg.nginx.appendConfig;
          virtualHosts = atlasLib.resolveNginxVirtualHosts cfg activeSubs;
          streams = atlasLib.resolveNginxStreams activeSubs;
        };

        networking = {
          nameservers = cfg.dns.resolvers;
          fallbackDns = cfg.dns.resolvers;
        };
      };

      networking.firewall = {
        allowedTCPPorts = extraFw.allowedTCPPorts;
        allowedUDPPorts = extraFw.allowedUDPPorts;
      };
    };
  }
  |> sensibleLib.sensibleConfig
