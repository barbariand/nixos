/*
# Sensible Homepage: Dashboard Manager
This module provides a declarative interface to configure the Homepage dashboard
(gethomepage.dev). It maps custom typed Nix options directly into the required
YAML configurations.

## Global Options
| Option                        | Type          | Description                                                                 |
|-------------------------------|---------------|-----------------------------------------------------------------------------|
| sensible.homepage.enable      | bool          | Global toggle for the Homepage service.                                     |
| sensible.homepage.port        | int (port)    | The port the Homepage web service will listen on (default: 8082).           |
| sensible.homepage.settings    | attrset       | Global settings map (theme, language, layout, etc.).                        |
| sensible.homepage.widgets     | list of attrs | Top-level widgets configuration (e.g., search, weather, resources).         |
| sensible.homepage.bookmarks   | list of attrs | Structured bookmark groups and links.                                       |
| sensible.homepage.services    | list of attrs | Structured service groups, application links, widgets, and API integrations.|
| sensible.homepage.environmentFile | path      | Path to a secure env file for secret interpolation (e.g., API tokens).      |
*/
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.sensible.homepage;
in {
  options.sensible.homepage = {
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
      default = [
      ];
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

  config = mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      settings = cfg.settings;
      widgets = cfg.widgets;
      bookmarks = cfg.bookmarks;
      services = cfg.services;
      environmentFile = cfg.environmentFile;

      allowedHosts = lib.concatStringsSep "," cfg.allowedHosts;
    };
    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
