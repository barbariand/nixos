{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    loki = {
      enable = mkEnableOption "Loki/Alloy logging integration";

      serverNode = mkOption {
        type = types.str;
        description = "The hostname of the machine acting as the central Loki server.";
      };

      domain = mkOption {
        type = types.str;
        example = "logs.simd.me";
        description = "Fully qualified domain name for the Loki push endpoint.";
      };

      port = mkOption {
        type = types.port;
        default = 3100;
        description = "Port for Loki HTTP listen address.";
      };

      grafanaPort = mkOption {
        type = types.port;
        default = 3000;
        description = "Port for Grafana HTTP listen address.";
      };

      retentionPeriod = mkOption {
        type = types.str;
        default = "28d";
        description = "Retention period for Loki logs.";
      };

      secretKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the secret key file for Grafana security. Required on the server node.";
      };
    };
  }
