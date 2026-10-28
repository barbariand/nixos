{
  cfg,
  lib,
  pkgs,
  ...
}: {
  assertions = [
    {
      assertion = cfg.custom.script != "";
      message = "sensible.ddns (custom): 'custom.script' must not be empty.";
    }
  ];

  system = {
    systemd.services.sensible-ddns = {
      description = "Sensible Custom Dynamic DNS Updater";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path =
        [
          pkgs.curl
          pkgs.jq
          pkgs.dnsutils
          pkgs.coreutils
        ]
        ++ cfg.custom.packages;
      environment.DDNS_DOMAINS = lib.concatStringsSep " " (lib.unique cfg.domains);
      serviceConfig =
        {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "sensible-ddns-update" cfg.custom.script;
        }
        // lib.optionalAttrs (cfg.custom.environmentFile != null) {
          EnvironmentFile = cfg.custom.environmentFile;
        };
    };

    systemd.timers.sensible-ddns = {
      description = "Timer for Sensible Custom Dynamic DNS Updater";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };
  };
}
