{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.wifi;
in {
  options.sensible.wifi = {
    enable = mkEnableOption "Sensible WiFi configuration";
    
    matchInterfaces = mkOption {
      type = types.str;
      default = "wlp* wlan*";
      description = "Interface glob to match for systemd-networkd rules.";
    };
    
    secretsFile = mkOption {
      type = types.path;
      description = "Path to the age secrets file containing wpa_supplicant credentials.";
    };
    
    networks = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Network definitions for wpa_supplicant.";
    };
  };

  config = mkIf cfg.enable {
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
        dhcpV4Config = {
          RouteMetric = 300;
        };
        ipv6AcceptRAConfig = {
          RouteMetric = 300;
        };
      };
    };

    systemd.services.wpa_supplicant = {
      wants = ["agenix.service"];
      after = ["agenix.service"];

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
