{
  config,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.wifi;
in
  {
    condition = cfg.enable;

    system = {
      networking.networkmanager.enable = false;

      networking.wireless = {
        enable = true;
        userControlled = true;
        secretsFile = cfg.secretsFile;
        networks = cfg.networks;
      };

      networking.useNetworkd = true;

      systemd.network = {
        enable = true;
        networks."25-wireless" = {
          matchConfig.Name = cfg.matchInterfaces;
          networkConfig = {
            DHCP = "yes";
            IgnoreCarrierLoss = "3s";
          };
          dhcpV4Config.RouteMetric = cfg.routeMetric;
          ipv6AcceptRAConfig.RouteMetric = cfg.routeMetric;
        };
      };

      systemd.services.wpa_supplicant = {
        wants = ["agenix-install-secrets.service"];
        after = ["agenix-install-secrets.service"];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    };
  }
  |> sensibleLib.sensibleConfig
