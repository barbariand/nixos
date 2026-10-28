{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    wifi = mkOption {
      default = {};
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible WiFi configuration";

          matchInterfaces = mkOption {
            type = types.str;
            default = "wlp* wlan*";
            description = "Interface glob to match for systemd-networkd rules.";
          };

          routeMetric = mkOption {
            type = types.int;
            default = 300;
            description = "DHCPv4 and IPv6 RA route metric for wireless interfaces.";
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
      };
    };
  }
