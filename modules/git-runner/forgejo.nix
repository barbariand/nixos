{
  cfg,
  activeForgejoRunners,
  hostPackages,
  sharedEnv,
  lib,
  pkgs,
}:
with lib; let
  fCfg = cfg.forgejo;

  resolveLabels = conn:
    if conn.labels != null
    then conn.labels
    else if fCfg.labels != null
    then fCfg.labels
    else cfg.labels;

  formatConnection = _id: conn:
    recursiveUpdate {
      inherit (conn) url uuid name;
      labels = resolveLabels conn;
      insecure =
        if conn.insecure != null
        then conn.insecure
        else fCfg.insecure;
    }
    conn.extraSettings;

  baseConfig = {
    log = {
      level = fCfg.logLevel;
    };
    runner = {
      capacity = fCfg.capacity;
      timeout = fCfg.timeout;
      fetch_interval = fCfg.fetchInterval;
      insecure = fCfg.insecure;
      env_file = cfg.envFile;
    };
    server = {
      connections = mapAttrs formatConnection activeForgejoRunners;
    };
    cache = {
      enabled = fCfg.cache.enable;
      dir = fCfg.cache.dir;
      host = fCfg.cache.host;
      port = fCfg.cache.port;
    };
  };

  finalConfig = recursiveUpdate baseConfig fCfg.extraSettings;
  baseConfigFile = (pkgs.formats.yaml {}).generate "forgejo-runner-base.yaml" finalConfig;
in {
  systemd.services.git-runner-forgejo = mkIf (activeForgejoRunners != {}) {
    description = "Forgejo Actions Runner CI";
    after = [
      "network-online.target"
      "nix-daemon.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    path = hostPackages;
    environment = sharedEnv;

    serviceConfig = {
      User = "git-runner";
      Group = "git-runner";
      DynamicUser = false;
      StateDirectory = "git-runner/forgejo";
      RuntimeDirectory = "git-runner-forgejo";
      RuntimeDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/git-runner/forgejo";

      CPUWeight = cfg.priority.cpuWeight;
      IOWeight = cfg.priority.ioWeight;
      MemoryHigh = "10G";
      MemoryMax = "12G";
      OOMScoreAdjust = cfg.priority.oomScoreAdjust;

      Restart = "always";
      RestartSec = "10s";
      RestartSteps = 5;
      RestartMaxDelaySec = "5m";

      LogRateLimitIntervalSec = "30s";
      LogRateLimitBurst = 50;

      ExecStartPre = pkgs.writeShellScript "forgejo-runner-build-config" ''
        set -euo pipefail

        CONFIG_DEST="/run/git-runner-forgejo/config.yaml"
        cp "${baseConfigFile}" "$CONFIG_DEST"
        chmod 0600 "$CONFIG_DEST"

        while IFS='=' read -r key val || [ -n "$key" ]; do
          [[ -z "$key" || "$key" =~ ^# ]] && continue

          key=$(echo "$key" | xargs)
          val=$(echo "$val" | xargs)
          val="''${val%\"}"
          val="''${val#\"}"

          ${pkgs.yq-go}/bin/yq -i \
            "select(.server.connections.$key != null) | .server.connections.$key.token = \"$val\"" \
            "$CONFIG_DEST"
        done < "${toString fCfg.tokenEnvFile}"
      '';

      ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner daemon --config /run/git-runner-forgejo/config.yaml";
    };
  };
}
