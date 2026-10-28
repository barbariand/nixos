{
  cfg,
  config,
  pkgs,
}: let
  hddWatchdogScript = pkgs.writeShellScript "attic-hdd-watchdog" ''
    set -euo pipefail
    STORAGE_PATH="${toString cfg.storagePath}"
    MAX_PCT=${toString cfg.maxDiskUsagePercent}

    if ! ${pkgs.util-linux}/bin/mountpoint -q /data; then
      echo "ERROR: /data is not mounted. Skipping Attic storage operations." >&2
      exit 1
    fi

    USAGE_PCT=$(${pkgs.coreutils}/bin/df --output=pcent "$STORAGE_PATH" | ${pkgs.coreutils}/bin/tail -n 1 | ${pkgs.coreutils}/bin/tr -dc '0-9')
    echo "Attic HDD usage at ''${USAGE_PCT}% (Threshold: ''${MAX_PCT}%)"

    if [ "$USAGE_PCT" -ge "$MAX_PCT" ]; then
      echo "WARNING: HDD usage (''${USAGE_PCT}%) exceeded threshold (''${MAX_PCT}%). Enforcing emergency retention (${cfg.garbageCollection.emergencyRetentionPeriod})..."
      ${pkgs.postgresql}/bin/psql -U atticd -d atticd -c "
        UPDATE cache
        SET retention_period = EXTRACT(EPOCH FROM INTERVAL '${cfg.garbageCollection.emergencyRetentionPeriod}')::INTEGER;
      " || true
    fi

    echo "Triggering atticd-gc oneshot sweep..."
    ${pkgs.systemd}/bin/systemctl start atticd-gc.service
  '';
in {
  systemd.services.atticd-gc = {
    description = "Attic Binary Cache Garbage Collection Sweep";
    after = [
      "postgresql.service"
      "atticd.service"
      "data.mount"
    ];
    requires = ["postgresql.service"];
    unitConfig.RequiresMountsFor = [(toString cfg.storagePath)];
    serviceConfig = {
      Type = "oneshot";
      User = "atticd";
      Group = "atticd";
      EnvironmentFile = cfg.environmentFile;
      ReadWritePaths = [(toString cfg.storagePath)];
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      ExecStart = "${config.services.atticd.package}/bin/atticd --mode garbage-collector-once -f /etc/atticd.toml";
    };
  };

  systemd.services.attic-hdd-watchdog = {
    description = "Attic HDD Capacity Watchdog and GC Enforcer";
    after = [
      "postgresql.service"
      "atticd.service"
      "data.mount"
    ];
    requires = ["postgresql.service"];
    unitConfig.RequiresMountsFor = [(toString cfg.storagePath)];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = hddWatchdogScript;
    };
  };

  systemd.timers.attic-hdd-watchdog = {
    description = "Periodic Attic HDD Capacity Check and Garbage Collection";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 02,14:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
