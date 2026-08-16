{
  lib,
  sensible_option,
  ...
}:
with lib;
  sensible_option {
    homepage = mkOption {
      default = {};
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible Homepage Dashboard";

          port = mkOption {
            type = types.port;
            default = 8082;
            description = "The port on which the homepage service should listen.";
          };

          settings = mkOption {
            type = types.attrs;
            default = {
              title = "Sensible Dashboard";
              background = {
                image = "https://images.unsplash.com/photo-1579546929518-9e396f3cc809";
                blur = "sm";
                saturate = 50;
                brightness = 50;
              };
              theme = "dark";
              layout = {
                iconStyle = "nord";
              };
            };
            description = "Global configuration settings for settings.yaml.";
          };

          widgets = mkOption {
            type = types.listOf types.anything;
            default = [];
            description = "List of widget definitions for widgets.yaml.";
          };

          bookmarks = mkOption {
            type = types.listOf types.anything;
            default = [];
            description = "List of bookmark categories and links for bookmarks.yaml.";
          };

          services = mkOption {
            type = types.listOf types.anything;
            default = [];
            description = "List of service categories and application cards for services.yaml.";
          };

          allowedHosts = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Hosts that homepage-dashboard will be running under.";
          };

          environmentFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to an environment file containing secrets (e.g., HOMEPAGE_VAR_GRAFANA_TOKEN).
              These variables can be used in the configuration using the {{HOMEPAGE_VAR_NAME}} syntax.
              Usually points to a file decrypted by agenix.
            '';
          };
        };
      };
    };
  }
