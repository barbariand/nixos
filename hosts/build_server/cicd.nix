{config, ...}: {
  sensible = {
    attic = {
      enable = true;
      port = 5000;
      apiEndpoint = "https://cache.simd.me/";
      environmentFile = config.age.secrets.atticd-env.path;
      storagePath = "/data/attic/storage";
      cacheName = "simd";
      publicPull = true;
      maxDiskUsagePercent = 80;

      garbageCollection = {
        interval = "12 hours";
      };
    };

    git_runner = {
      enable = true;
      maxJobsPerBuild = 2;
      coresPerJob = 4;
      buildTmpDir = "/var/tmp/nix-build";
      envFile = null;
      labels = [
        "nixos:host"
        "nix:host"
        "linux-x86_64:host"
        "build_server:host"
      ];

      forgejo = {
        capacity = 2;
        fetchInterval = "15s";
        tokenEnvFile = config.age.secrets.forgejo-runner-tokens.path;

        runners = {
          sensible = {
            name = "build_server";
            url = "https://git.urgobalt.dev";
            uuid = "4aea739d-8306-43be-a259-2e784c745afe";
          };

          barbariand = {
            name = "build_server";
            url = "https://git.urgobalt.dev";
            uuid = "4e652772-7d5d-4beb-a432-d47ba3f8122a";
          };
        };
      };

      # github = {
      #   ephemeral = false;
      #   replace = true;
      #   tokenFile = config.age.secrets.github-runner-token.path;
      #
      #   runners = {
      #     main = {
      #       name = "build_server";
      #       url = "https://github.com/Barbariand11";
      #     };
      #   };
      # };
    };
  };

  programs.ssh.knownHosts."git.urgobalt.dev".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINxOp2Vbzsr0U4FZZzhkd4ri1cTEdMLrGR2g/wchDlES";
  programs.ssh.extraConfig = ''
    Host git.urgobalt.dev
      StrictHostKeyChecking accept-new
      IdentityFile ${config.age.secrets.ci-ssh-key.path}
  '';

  nix.settings.builders-use-substitutes = true;
}
