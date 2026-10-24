{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.ci;
  atticCfg = cfg.attic;
  runnerCfg = cfg.runner;
  gcCfg = cfg.storeGc;

  gibToBytes = n: n * 1024 * 1024 * 1024;

  hddWatchdogScript = pkgs.writeShellScript "attic-hdd-watchdog" ''
    set -euo pipefail
    STORAGE_PATH="${toString atticCfg.storagePath}"
    MAX_PCT=${toString atticCfg.maxDiskUsagePercent}

    if ! ${pkgs.util-linux}/bin/mountpoint -q /data; then
      echo "ERROR: /data is not mounted. Skipping Attic storage operations." >&2
      exit 1
    fi

    USAGE_PCT=$(${pkgs.coreutils}/bin/df --output=pcent "$STORAGE_PATH" | ${pkgs.coreutils}/bin/tail -n 1 | ${pkgs.coreutils}/bin/tr -dc '0-9')
    echo "Attic HDD usage at ''${USAGE_PCT}% (Threshold: ''${MAX_PCT}%)"

    if [ "$USAGE_PCT" -ge "$MAX_PCT" ]; then
      echo "WARNING: HDD usage (''${USAGE_PCT}%) exceeded threshold (''${MAX_PCT}%). Enforcing emergency retention (${atticCfg.garbageCollection.emergencyRetentionPeriod}) and triggering immediate GC..."
      ${pkgs.postgresql}/bin/psql -U atticd -d atticd -c "
        UPDATE cache
        SET retention_period = EXTRACT(EPOCH FROM INTERVAL '${atticCfg.garbageCollection.emergencyRetentionPeriod}')::INTEGER;
      " || true
    fi

    echo "Triggering atticd-gc oneshot sweep..."
    ${pkgs.systemd}/bin/systemctl start atticd-gc.service
  '';
in
  {
    condition = cfg.enable;

    assertions = [
      {
        assertion = atticCfg.enable -> hasSuffix "/" atticCfg.apiEndpoint;
        message = "sensible.ci.attic.apiEndpoint must end with a trailing slash (e.g. 'http://10.55.0.5:5000/').";
      }
      {
        assertion = gcCfg.minFreeGiB < gcCfg.maxFreeGiB;
        message = "sensible.ci.storeGc: minFreeGiB must be strictly less than maxFreeGiB.";
      }
    ];

    system = {
      # -------------------------------------------------------------------------
      # 1. Nix Daemon, SSD GC & I/O / OOM Guardrails
      # -------------------------------------------------------------------------
      nix = {
        settings = {
          max-jobs = runnerCfg.maxJobsPerBuild;
          cores = runnerCfg.coresPerJob;
          builders-use-substitutes = true;
          auto-optimise-store = false; # Undvik tungt SSD-slitage under pågående CI-byggen

          min-free = gibToBytes gcCfg.minFreeGiB;
          max-free = gibToBytes gcCfg.maxFreeGiB;

          trusted-users = ["root"] ++ optional runnerCfg.enable "gitea-runner";
        };

        daemonCPUSchedPolicy = "batch";
        daemonIOSchedClass = "idle";

        gc = mkIf gcCfg.enable {
          automatic = true;
          dates = gcCfg.dates;
          persistent = true;
          options = "--delete-older-than ${toString gcCfg.keepDays}d";
        };

        optimise = {
          automatic = true;
          dates = ["Sun 04:30"];
        };
      };

      # Dirigera om nix-daemonens temporära byggfiler från RAM (/tmp tmpfs) till SSD
      systemd.services.nix-daemon = {
        environment.TMPDIR = toString runnerCfg.buildTmpDir;
        serviceConfig = {
          OOMScoreAdjust = 250;
           MemoryHigh = "12G";
          MemoryMax = "14G";
        };
      };

      # Skapa nödvändiga kataloger och rensa gamla byggrester i /var/tmp/nix-build automatiskt
      systemd.tmpfiles.rules = [
        "d ${toString runnerCfg.buildTmpDir} 0755 root root 1d"
        "d /data/attic 0750 atticd atticd -"
        "d ${toString atticCfg.storagePath} 0750 atticd atticd -"
      ];

      # -------------------------------------------------------------------------
      # 2. PostgreSQL på SSD (/var/lib/postgresql) för snabb metadata-hantering
      # -------------------------------------------------------------------------
      services.postgresql = mkIf atticCfg.enable {
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
          random_page_cost = 1.1; # Optimerad för SSD
          effective_io_concurrency = 200;
          synchronous_commit = "off"; # Minskar SSD write-amplification vid chunk-indexering
          wal_compression = "zstd";
        };
      };

      # -------------------------------------------------------------------------
      # 3. Attic Binary Cache (Metadata i PostgreSQL på SSD, Chunks på /data HDD)
      # -------------------------------------------------------------------------
      users.users.atticd = mkIf atticCfg.enable {
        isSystemUser = true;
        group = "atticd";
      };
      users.groups.atticd = mkIf atticCfg.enable {};

      services.atticd = mkIf atticCfg.enable {
        enable = true;
        user = "atticd";
        group = "atticd";
        environmentFile = atticCfg.environmentFile;

        settings = {
          listen = "${atticCfg.listenAddress}:${toString atticCfg.port}";
          api-endpoint = atticCfg.apiEndpoint;

          database = {
            url = "postgresql:///atticd?host=/run/postgresql";
          };

          storage = {
            type = "local";
            path = toString atticCfg.storagePath;
          };

          chunking = {
            nar-size-threshold = atticCfg.chunking.narSizeThreshold;
            min-size = atticCfg.chunking.minSize;
            avg-size = atticCfg.chunking.avgSize;
            max-size = atticCfg.chunking.maxSize;
          };

          compression = {
            type = "zstd";
            level = 6;
          };

          garbage-collection = {
            interval = atticCfg.garbageCollection.interval;
            default-retention-period = atticCfg.garbageCollection.defaultRetentionPeriod;
          };
        };
      };

      # Säkerställ att atticd aldrig skriver till en omonterad /data-katalog på rot-SSD:n
      systemd.services.atticd = mkIf atticCfg.enable {
        after = ["postgresql.service" "data.mount"];
        requires = ["postgresql.service"];
        unitConfig.RequiresMountsFor = [
          "/var/lib/postgresql"
          (toString atticCfg.storagePath)
        ];
        serviceConfig = {
          ReadWritePaths = [ (toString atticCfg.storagePath) ];
        };
      };

      # Dedikerad oneshot-tjänst för deterministisk Attic GC
      systemd.services.atticd-gc = mkIf atticCfg.enable {
        description = "Attic Binary Cache Garbage Collection Sweep";
        after = ["postgresql.service" "atticd.service" "data.mount"];
        requires = ["postgresql.service"];
        unitConfig.RequiresMountsFor = [ (toString atticCfg.storagePath) ];
        serviceConfig = {
          Type = "oneshot";
          User = "atticd";
          Group = "atticd";
          EnvironmentFile = atticCfg.environmentFile;
          ReadWritePaths = [ (toString atticCfg.storagePath) ];
          IOSchedulingClass = "idle";
          CPUSchedulingPolicy = "idle";
          ExecStart = "${config.services.atticd.package}/bin/atticd --mode garbage-collector-once -f /etc/atticd.toml";
        };
      };

      # Periodisk HDD-watchdog som övervakar /data och tvingar fram rensning vid behov
      systemd.services.attic-hdd-watchdog = mkIf atticCfg.enable {
        description = "Attic HDD Capacity Watchdog and GC Enforcer";
        after = ["postgresql.service" "atticd.service" "data.mount"];
        requires = ["postgresql.service"];
        unitConfig.RequiresMountsFor = [ (toString atticCfg.storagePath) ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = hddWatchdogScript;
        };
      };

      systemd.timers.attic-hdd-watchdog = mkIf atticCfg.enable {
        description = "Periodic Attic HDD Capacity Check and Garbage Collection";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*-*-* 02,14:00:00";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };

      # -------------------------------------------------------------------------
      # 4. Forgejo Actions Runner (Host Execution Mode + Cgroup Guardrails)
      # -------------------------------------------------------------------------
      users.users.gitea-runner = mkIf runnerCfg.enable {
        isSystemUser = true;
        group = "gitea-runner";
        home = "/var/lib/gitea-runner";
        createHome = true;
      };
      users.groups.gitea-runner = mkIf runnerCfg.enable {};

      services.gitea-actions-runner = mkIf runnerCfg.enable {
        package = pkgs.forgejo-runner;
        instances.ci = {
          enable = true;
          name = runnerCfg.name;
          url = runnerCfg.url;
          tokenFile = runnerCfg.tokenFile;
          labels = runnerCfg.labels;

          hostPackages = with pkgs; [
            attic-client
            bash
            coreutils
            curl
            findutils
            gawk
            git
            gnugrep
            gnused
            gnutar
            gzip
            jq
            just
            nix
            openssh
            xz
            zstd
          ];

          settings = {
            log.level = "info";
            runner = {
              capacity = runnerCfg.capacity;
              timeout = "3h";
              insecure = false;
            };
            cache.enabled = false;
          };
        };
      };

      systemd.services.gitea-runner-ci = mkIf runnerCfg.enable {
        after = ["network-online.target" "nix-daemon.service"];
        wants = ["network-online.target"];
        environment = {
          TMPDIR = toString runnerCfg.buildTmpDir;
          NIX_CONFIG = ''
            experimental-features = nix-command flakes pipe-operators
            max-jobs = ${toString runnerCfg.maxJobsPerBuild}
            cores = ${toString runnerCfg.coresPerJob}
          '';
        };
        serviceConfig = {
          User = mkForce "gitea-runner";
          Group = mkForce "gitea-runner";
          DynamicUser = mkForce false;
          StateDirectory = "gitea-runner";
          CPUWeight = 50;
          IOWeight = 50;
          MemoryHigh = "10G";
          MemoryMax = "12G";
          OOMScoreAdjust = 500;
        };
      };

      environment.systemPackages = mkIf atticCfg.enable [
        pkgs.attic-client
        config.services.atticd.package
      ];

      networking.firewall.allowedTCPPorts = mkIf (atticCfg.enable && atticCfg.openFirewall) [
        atticCfg.port
      ];
    };
  }
  |> sensibleLib.sensibleConfig
