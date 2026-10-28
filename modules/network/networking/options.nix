{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    networking = mkOption {
      default = {};
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable sensible base networking and systemd-resolved configuration.";
          };

          nameservers = mkOption {
            type = types.listOf types.str;
            default = ["1.1.1.1"];
          };

          fallbackDns = mkOption {
            type = types.listOf types.str;
            default = [
              "1.1.1.1"
              "9.9.9.9"
            ];
          };

          dnsOverTls = mkOption {
            type = types.str;
            default = "opportunistic";
          };
        };
      };
    };
  }
