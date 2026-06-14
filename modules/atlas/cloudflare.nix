{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.atlas;
in {
  config = mkIf (cfg.enable && cfg.cloudflare.enable) {
    services.cloudflare-dyndns = {
      enable = true;
      apiTokenFile = cfg.cloudflare.tokenFile;
      domains = let
        # Filtrerar bort alla subdomäner som är märkta som interna
        activeSubs = filterAttrs (n: s: s.enable && s.cloudflare.enable && s.visibility == "public") cfg.subdomains;
      in
        [cfg.baseDomain] ++ (mapAttrsToList (n: v: "${n}.${cfg.baseDomain}") activeSubs);
    };
  };
}
