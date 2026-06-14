{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.atlas;
in {
  config = mkIf (cfg.enable && cfg.acme.enable) {
    security.acme = {
      acceptTerms = true;
      defaults = {
        inherit (cfg.acme) email environmentFile;
        dnsResolver = "${head cfg.dns.resolvers}:53";
        group = "nginx";
        dnsProvider = "cloudflare";
        webroot = null;
        reloadServices = (optional cfg.unbound.enable "unbound") ++ (optional cfg.nginx.enable "nginx");
      };
      certs."${cfg.baseDomain}" = {
        domain = cfg.baseDomain;
        extraDomainNames = ["*.${cfg.baseDomain}"];
      };
    };
  };
}
