{ cfg, lib, ... }:
{
  assertions = [
    {
      assertion = cfg.inadyn.username != null && cfg.inadyn.passwordFile != null;
      message = "sensible.ddns (inadyn): both 'inadyn.username' and 'inadyn.passwordFile' must be set.";
    }
  ];

  system = {
    services.inadyn = {
      enable = true;
      settings = lib.recursiveUpdate {
        provider.${cfg.inadyn.provider} = {
          username = cfg.inadyn.username;
          password-file = cfg.inadyn.passwordFile;
          hostname = lib.unique cfg.domains;
        };
      } cfg.inadyn.extraSettings;
    };
  };
}
