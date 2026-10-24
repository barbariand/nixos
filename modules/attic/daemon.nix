{
  cfg,
  lib,
}: {
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };
  users.groups.atticd = {};

  systemd.tmpfiles.rules = [
    "d ${builtins.dirOf (toString cfg.storagePath)} 0750 atticd atticd -"
    "d ${toString cfg.storagePath} 0750 atticd atticd -"
  ];

  services.atticd = {
    enable = true;
    user = "atticd";
    group = "atticd";
    environmentFile = cfg.environmentFile;

    settings = {
      listen = "${cfg.listenAddress}:${toString cfg.port}";
      api-endpoint = cfg.apiEndpoint;

      database = {
        url = "postgresql:///atticd?host=/run/postgresql";
      };

      storage = {
        type = "local";
        path = toString cfg.storagePath;
      };

      chunking = {
        nar-size-threshold = cfg.chunking.narSizeThreshold;
        min-size = cfg.chunking.minSize;
        avg-size = cfg.chunking.avgSize;
        max-size = cfg.chunking.maxSize;
      };

      compression = {
        type = "zstd";
        level = 6;
      };

      garbage-collection = {
        interval = cfg.garbageCollection.interval;
        default-retention-period = cfg.garbageCollection.defaultRetentionPeriod;
      };
    };
  };

  systemd.services.atticd = {
    after = ["postgresql.service" "data.mount"];
    requires = ["postgresql.service"];
    unitConfig.RequiresMountsFor = [
      "/var/lib/postgresql"
      (toString cfg.storagePath)
    ];
    serviceConfig = {
      ReadWritePaths = [(toString cfg.storagePath)];
    };
  };
}
