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
        defaultRetentionPeriod = "7 days";
        emergencyRetentionPeriod = "3 days";
      };
    };

    forgejo-runner = {
      enable = true;
      capacity = 2;
      maxJobsPerBuild = 2;
      coresPerJob = 4;
      buildTmpDir = "/var/tmp/nix-build";
      envFile = null;
      tokenEnvFile = config.age.secrets.forgejo-runner-tokens.path;

      connections = {
        sensible = {
          name = "build_server";
          url = "https://git.urgobalt.dev";
          uuid = "4aea739d-8306-43be-a259-2e784c745afe";
          labels = [
            "nixos:host"
            "nix:host"
            "linux-x86_64:host"
            "build_server:host"
          ];
        };

        barbariand = {
          name = "build_server";
          url = "https://git.urgobalt.dev";
          uuid = "4e652772-7d5d-4beb-a432-d47ba3f8122a";
          labels = [
            "nixos:host"
            "nix:host"
            "linux-x86_64:host"
            "build_server:host"
          ];
        };
      };
    };
  };

  age.secrets.forgejo-runner-tokens = {
    owner = "forgejo-runner";
    group = "forgejo-runner";
    mode = "0400";
  };

  nix.settings.builders-use-substitutes = true;
}
