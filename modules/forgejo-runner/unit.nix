{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.forgejo-runner;

  pConfig = import ./config.nix {inherit cfg lib pkgs;};
  pService = import ./service.nix {inherit cfg lib pkgs pConfig;};
  pDaemon = import ./daemon-tuning.nix {inherit cfg;};
in
  {
    condition = cfg.enable;

    system = {
      users = pService.users;
      nix = pDaemon.nix;
      systemd.tmpfiles.rules = pDaemon.systemd.tmpfiles.rules;

      systemd.services = {
        forgejo-runner-ci = pService.systemd.services.forgejo-runner-ci;
        nix-daemon = pDaemon.systemd.services.nix-daemon;
      };
    };
  }
  |> sensibleLib.sensibleConfig
