{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.forgejo-runner;

  pService = import ./service.nix {inherit cfg lib pkgs;};
  pDaemon = import ./daemon-tuning.nix {inherit cfg;};
in
  {
    condition = cfg.enable;

    system = {
      users = pService.users;
      nix = pDaemon.nix;
      systemd.tmpfiles.rules = pDaemon.systemd.tmpfiles.rules;
      services.gitea-actions-runner = pService.services.gitea-actions-runner;

      systemd.services = {
        gitea-runner-ci = pService.systemd.services.gitea-runner-ci;
        nix-daemon = pDaemon.systemd.services.nix-daemon;
      };
    };
  }
  |> sensibleLib.sensibleConfig
