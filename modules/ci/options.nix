{
  lib,
  sensible_option,
  ...
}:
with lib;
sensible_option {
  ci = mkOption {
    default = {};
    description = "Sensible CI/CD & Binary Cache Stack (Attic + PostgreSQL + Forgejo Runner + Disk Guardrails).";
    type = types.submodule {
      options = {
        enable = mkEnableOption "Sensible Nix CI/CD and Attic binary cache stack";

        attic = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Attic binary cache server backed by PostgreSQL on SSD and chunk storage on HDD.";
          };

          listenAddress = mkOption {
            type = types.str;
            default = "0.0.0.0";
          };

          port = mkOption {
            type = types.port;
            default = 5000;
          };

          apiEndpoint = mkOption {
            type = types.str;
            default = "http://10.55.0.5:5000/";
            description = "Canonical URL to the Attic server (must end with a trailing slash).";
          };

          environmentFile = mkOption {
            type = types.path;
            description = "Path to secret file containing ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64.";
          };

          storagePath = mkOption {
            type = types.path;
            default = "/data/attic/storage";
            description = "Directory on the mechanical HDD for deduplicated NAR chunks.";
          };

          maxDiskUsagePercent = mkOption {
            type = types.ints.between 10 95;
            default = 80;
            description = "High-water mark percentage on the HDD mount that triggers aggressive emergency retention.";
          };

          chunking = {
            narSizeThreshold = mkOption {
              type = types.int;
              default = 65536; # 64 KiB
              description = "Minimum NAR size in bytes before FastCDC chunking is applied.";
            };
            minSize = mkOption {
              type = types.int;
              default = 16384; # 16 KiB
            };
            avgSize = mkOption {
              type = types.int;
              default = 65536; # 64 KiB
            };
            maxSize = mkOption {
              type = types.int;
              default = 262144; # 256 KiB
            };
          };

          garbageCollection = {
            interval = mkOption {
              type = types.str;
              default = "12 hours";
              description = "Internal Attic daemon GC check interval.";
            };
            defaultRetentionPeriod = mkOption {
              type = types.str;
              default = "30 days";
              description = "Default retention window for cached NARs before chunk reclamation.";
            };
            emergencyRetentionPeriod = mkOption {
              type = types.str;
              default = "7 days";
              description = "Retention period enforced when HDD usage exceeds maxDiskUsagePercent.";
            };
          };

          openFirewall = mkOption {
            type = types.bool;
            default = true;
          };
        };

        runner = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Forgejo Actions runner in host execution mode.";
          };

          name = mkOption {
            type = types.str;
            default = "build-server-nix";
          };

          url = mkOption {
            type = types.str;
            description = "Forgejo instance URL (e.g. 'https://git.urgobalt.dev' or 'https://git.simd.me').";
          };

          tokenFile = mkOption {
            type = types.path;
            description = "Path to secret file containing TOKEN=<runner_registration_token>.";
          };

          capacity = mkOption {
            type = types.ints.positive;
            default = 2;
            description = "Max concurrent CI jobs (kept at 2 to prevent OOM on 16 GB RAM).";
          };

          maxJobsPerBuild = mkOption {
            type = types.ints.positive;
            default = 2;
            description = "Nix max-jobs per build invocation.";
          };

          coresPerJob = mkOption {
            type = types.ints.positive;
            default = 4;
            description = "CPU cores allocated per derivation build.";
          };

          buildTmpDir = mkOption {
            type = types.path;
            default = "/var/tmp/nix-build";
            description = "SSD-backed temporary build directory so large builds never exhaust RAM tmpfs.";
          };

          labels = mkOption {
            type = types.listOf types.str;
            default = [
              "nixos:host"
              "nix:host"
              "linux-x86_64:host"
            ];
          };
        };

        storeGc = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable automated Nix store GC and free-space watermarks on the SSD.";
          };

          minFreeGiB = mkOption {
            type = types.ints.positive;
            default = 80;
            description = "Trigger on-the-fly Nix GC during builds if SSD free space drops below this value (GiB).";
          };

          maxFreeGiB = mkOption {
            type = types.ints.positive;
            default = 250;
            description = "Stop on-the-fly Nix GC once SSD free space reaches this value (GiB).";
          };

          keepDays = mkOption {
            type = types.ints.positive;
            default = 14;
            description = "Delete unreferenced store paths and old generations older than this many days.";
          };

          dates = mkOption {
            type = types.str;
            default = "03:15";
          };
        };
      };
    };
  };
}
