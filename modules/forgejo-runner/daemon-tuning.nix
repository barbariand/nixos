{cfg}: {
  nix.settings.trusted-users = ["gitea-runner"];

  systemd.tmpfiles.rules = [
    "d ${toString cfg.buildTmpDir} 0755 root root 1d"
  ];

  systemd.services.nix-daemon = {
    environment.TMPDIR = toString cfg.buildTmpDir;
    serviceConfig = {
      OOMScoreAdjust = 250;
      MemoryHigh = "12G";
      MemoryMax = "14G";
    };
  };
}
