{
  cfg,
  lib,
  ...
}: {
  assertions = [
    {
      assertion = cfg.ddclient.passwordFile != null;
      message = "sensible.ddns (ddclient): 'ddclient.passwordFile' must be set.";
    }
  ];

  system = {
    services.ddclient = {
      enable = true;
      interval = cfg.interval;
      protocol = cfg.ddclient.protocol;
      server = lib.mkIf (cfg.ddclient.server != null) cfg.ddclient.server;
      zone = lib.mkIf (cfg.ddclient.zone != null) cfg.ddclient.zone;
      username = lib.mkIf (cfg.ddclient.username != null) cfg.ddclient.username;
      passwordFile = cfg.ddclient.passwordFile;
      domains = lib.unique cfg.domains;
      usev4 =
        if cfg.ipv4
        then "webv4, webv4=ipify-ipv4"
        else "disabled";
      usev6 =
        if cfg.ipv6
        then "webv6, webv6=ipify-ipv6"
        else "disabled";
      extraConfig = cfg.ddclient.extraConfig;
    };
  };
}
