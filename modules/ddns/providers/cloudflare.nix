{ cfg, lib, ... }:
{
  assertions = [
    {
      assertion = cfg.cloudflare.tokenFile != null;
      message = "sensible.ddns (cloudflare): 'cloudflare.tokenFile' must be set.";
    }
  ];

  system = {
    services.cloudflare-dyndns = {
      enable = true;
      apiTokenFile = cfg.cloudflare.tokenFile;
      domains = lib.unique cfg.domains;
      proxied = cfg.cloudflare.proxied;
      ipv4 = cfg.ipv4;
      ipv6 = cfg.ipv6;
    };
  };
}
