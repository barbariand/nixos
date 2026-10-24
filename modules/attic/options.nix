{
  lib,
  sensible_option,
  ...
}:
with lib;
sensible_option {
  attic = mkOption {
    default = {};
    description = "Sensible Attic binary cache server.";
    type = types.submodule {
      options = {
        enable = mkEnableOption "Sensible Attic binary cache server";

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
          default = "https://cache.simd.me/";
          description = "Canonical URL to Attic (must end with a trailing slash).";
        };

        environmentFile = mkOption {
          type = types.path;
          description = "Path to secret file containing ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64.";
        };

        storagePath = mkOption {
          type = types.path;
          default = "/data/attic/storage";
          description = "Directory on the HDD for deduplicated NAR chunks.";
        };

        cacheName = mkOption {
          type = types.str;
          default = "simd";
          description = "Attic cache name to provision on startup.";
        };

        publicPull = mkOption {
          type = types.bool;
          default = true;
          description = "Configure the cache for anonymous public pulls while keeping pushes authenticated.";
        };

        maxDiskUsagePercent = mkOption {
          type = types.ints.between 10 95;
          default = 80;
          description = "HDD mount utilization percentage triggering emergency retention.";
        };

        chunking = {
          narSizeThreshold = mkOption {
            type = types.int;
            default = 65536;
          };
          minSize = mkOption {
            type = types.int;
            default = 16384;
          };
          avgSize = mkOption {
            type = types.int;
            default = 65536;
          };
          maxSize = mkOption {
            type = types.int;
            default = 262144;
          };
        };

        garbageCollection = {
          interval = mkOption {
            type = types.str;
            default = "12 hours";
          };
          defaultRetentionPeriod = mkOption {
            type = types.str;
            default = "30 days";
          };
          emergencyRetentionPeriod = mkOption {
            type = types.str;
            default = "7 days";
          };
        };

        openFirewall = mkOption {
          type = types.bool;
          default = true;
        };
      };
    };
  };
}
