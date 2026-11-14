{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.git_runner;

  activeForgejoRunners = filterAttrs (_: r: r.enable) cfg.forgejo.runners;
  activeGithubRunners = filterAttrs (_: r: r.enable) cfg.github.runners;

  hostPackages = with pkgs; [
    attic-client
    bash
    coreutils
    curl
    findutils
    gawk
    git
    gnugrep
    gnused
    gnutar
    gzip
    jq
    just
    nix
    nodejs
    openssh
    xz
    yq-go
    zstd
  ];

  sharedEnv = {
    TMPDIR = toString cfg.buildTmpDir;
    NIX_CONFIG = ''
      experimental-features = nix-command flakes pipe-operators
      max-jobs = ${toString cfg.maxJobsPerBuild}
      cores = ${toString cfg.coresPerJob}
    '';
  };

  pDaemon = import ./daemon-tuning.nix {inherit cfg;};
  pForgejo = import ./forgejo.nix {
    inherit
      cfg
      activeForgejoRunners
      hostPackages
      sharedEnv
      lib
      pkgs
      ;
  };
  pGithub = import ./github.nix {
    inherit
      cfg
      activeGithubRunners
      hostPackages
      sharedEnv
      lib
      ;
  };
in
  {
    condition = cfg.enable;

    assertions =
      [
        {
          assertion = (activeForgejoRunners != {}) -> (cfg.forgejo.tokenEnvFile != null);
          message = "sensible.git_runner.forgejo: 'tokenEnvFile' must be set when at least one Forgejo runner is enabled.";
        }
      ]
      ++ (mapAttrsToList (id: r: {
          assertion = (r.tokenFile != null) || (cfg.github.tokenFile != null);
          message = "sensible.git_runner.github.runners.${id}: either 'tokenFile' or 'sensible.git_runner.github.tokenFile' must be set.";
        })
        activeGithubRunners);

    system = {
      users.users.git-runner = {
        isSystemUser = true;
        group = "git-runner";
        home = "/var/lib/git-runner";
        createHome = true;
      };
      users.groups.git-runner = {};

      nix = pDaemon.nix;
      systemd.tmpfiles.rules =
        pDaemon.systemd.tmpfiles.rules
        ++ [
          "d /var/lib/git-runner 0750 git-runner git-runner -"
          "d /var/lib/git-runner/forgejo 0750 git-runner git-runner -"
        ];

      systemd.services = {
        nix-daemon = pDaemon.systemd.services.nix-daemon;
        git-runner-forgejo = pForgejo.systemd.services.git-runner-forgejo;
      };

      services.github-runners = pGithub.services.github-runners;
    };
  }
  |> sensibleLib.sensibleConfig
