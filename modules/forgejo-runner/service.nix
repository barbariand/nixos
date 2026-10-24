{
  cfg,
  lib,
  pkgs,
}:
with lib; {
  users.users.gitea-runner = {
    isSystemUser = true;
    group = "gitea-runner";
    home = "/var/lib/gitea-runner";
    createHome = true;
  };
  users.groups.gitea-runner = {};

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.ci = {
      enable = true;
      name = cfg.name;
      url = cfg.url;
      tokenFile = cfg.tokenFile;
      labels = cfg.labels;

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
        openssh
        xz
        zstd
      ];

      settings = {
        log.level = "info";
        runner = {
          capacity = cfg.capacity;
          timeout = "3h";
          insecure = false;
        };
        cache.enabled = false;
      };
    };
  };

  systemd.services.gitea-runner-ci = {
    after = ["network-online.target" "nix-daemon.service"];
    wants = ["network-online.target"];
    environment = {
      TMPDIR = toString cfg.buildTmpDir;
      NIX_CONFIG = ''
        experimental-features = nix-command flakes pipe-operators
        max-jobs = ${toString cfg.maxJobsPerBuild}
        cores = ${toString cfg.coresPerJob}
      '';
    };
    serviceConfig = {
      User = mkForce "gitea-runner";
      Group = mkForce "gitea-runner";
      DynamicUser = mkForce false;
      StateDirectory = "gitea-runner";
      CPUWeight = 50;
      IOWeight = 50;
      MemoryHigh = "10G";
      MemoryMax = "12G";
      OOMScoreAdjust = 500;
    };
  };
}
