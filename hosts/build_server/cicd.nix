{ config, ... }: {
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
    };

    forgejo-runner = {
      enable = true;
      name = "build_server";
      url = "https://git.urgobalt.dev";
      tokenFile = config.age.secrets.urgobalt-forgejo-runner.path;
      capacity = 2;
      maxJobsPerBuild = 2;
      coresPerJob = 4;
      buildTmpDir = "/var/tmp/nix-build";
    };
  };

  nix.settings.builders-use-substitutes = true;
}
