{
  lib,
  config,
  sensibleLib,
  ...
}:
with sensibleLib; let
  cfg = config.sensible.homepage;
in
  {
    condition = cfg.enable;

    system = {
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
  |> sensibleConfig
