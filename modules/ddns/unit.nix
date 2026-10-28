{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.ddns;

  pCloudflare = import ./providers/cloudflare.nix {inherit cfg lib pkgs;};
  pInadyn = import ./providers/inadyn.nix {inherit cfg lib pkgs;};
  pDdclient = import ./providers/ddclient.nix {inherit cfg lib pkgs;};
  pCustom = import ./providers/custom.nix {inherit cfg lib pkgs;};
in
  {
    condition = cfg.enable && cfg.domains != [];

    assertions = [
      {
        assertion = (cfg.enable && cfg.provider == "cloudflare") -> cfg.cloudflare.tokenFile != null;
        message = "sensible.ddns (cloudflare): 'cloudflare.tokenFile' must be set.";
      }
      {
        assertion =
          (cfg.enable && cfg.provider == "inadyn")
          -> (cfg.inadyn.username != null && cfg.inadyn.passwordFile != null);
        message = "sensible.ddns (inadyn): both 'inadyn.username' and 'inadyn.passwordFile' must be set.";
      }
      {
        assertion = (cfg.enable && cfg.provider == "ddclient") -> cfg.ddclient.passwordFile != null;
        message = "sensible.ddns (ddclient): 'ddclient.passwordFile' must be set.";
      }
      {
        assertion = (cfg.enable && cfg.provider == "custom") -> cfg.custom.script != "";
        message = "sensible.ddns (custom): 'custom.script' must not be empty.";
      }
    ];

    system = {
      services.cloudflare-dyndns =
        lib.mkIf (
          cfg.provider == "cloudflare"
        )
        pCloudflare.system.services.cloudflare-dyndns;
      services.inadyn = lib.mkIf (cfg.provider == "inadyn") pInadyn.system.services.inadyn;
      services.ddclient = lib.mkIf (cfg.provider == "ddclient") pDdclient.system.services.ddclient;
      systemd.services.sensible-ddns =
        lib.mkIf (
          cfg.provider == "custom"
        )
        pCustom.system.systemd.services.sensible-ddns;
      systemd.timers.sensible-ddns =
        lib.mkIf (
          cfg.provider == "custom"
        )
        pCustom.system.systemd.timers.sensible-ddns;
    };
  }
  |> sensibleLib.sensibleConfig
