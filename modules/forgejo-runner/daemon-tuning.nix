{cfg}: {
  nix.settings.trusted-users = ["forgejo-runner"];

  systemd.tmpfiles.rules = [
    "d ${toString cfg.buildTmpDir} 0775 forgejo-runner nixbld 1d"
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
