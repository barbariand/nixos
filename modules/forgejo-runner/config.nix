{
  cfg,
  lib,
  pkgs,
}:
with lib; let
  formatConnection = _name: conn:
    recursiveUpdate {
      inherit (conn) url uuid labels name;
      insecure =
        if conn.insecure != null
        then conn.insecure
        else cfg.insecure;
    }
    conn.extraSettings;

  baseConfig = {
    log = {
      level = cfg.logLevel;
    };
    runner = {
      capacity = cfg.capacity;
      timeout = cfg.timeout;
      insecure = cfg.insecure;
      env_file = cfg.envFile;
    };
    server = {
      connections = mapAttrs formatConnection cfg.connections;
    };
    cache = {
      enabled = cfg.cache.enable;
      dir = cfg.cache.dir;
      host = cfg.cache.host;
      port = cfg.cache.port;
    };
  };

  finalConfig = recursiveUpdate baseConfig cfg.extraSettings;
in {
  baseConfigFile = (pkgs.formats.yaml {}).generate "forgejo-runner-base.yaml" finalConfig;
}
