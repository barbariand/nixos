{
  cfg,
  pkgs,
}: {
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = "/var/lib/postgresql/16";
    ensureDatabases = ["atticd"];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
    settings = {
      shared_buffers = "512MB";
      effective_cache_size = "2GB";
      work_mem = "16MB";
      maintenance_work_mem = "128MB";
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      synchronous_commit = "off";
      wal_compression = "zstd";
    };
  };
}
