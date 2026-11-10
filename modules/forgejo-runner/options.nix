{
  lib,
  sensible_option,
  ...
}:
with lib; let
  connectionSubmodule = types.submodule ({name, ...}: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
        description = "Internal name of the connection (defaults to the attribute name).";
      };

      url = mkOption {
        type = types.str;
        example = "https://forgejo.example.com";
        description = "Forgejo instance URL.";
      };

      uuid = mkOption {
        type = types.str;
        description = "Pre-registered runner UUID for this instance.";
      };

      labels = mkOption {
        type = types.listOf types.str;
        default = [
          "nixos:host"
          "nix:host"
          "linux-x86_64:host"
        ];
        description = "Job labels advertised for this connection.";
      };

      insecure = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Allow insecure TLS connection to this specific instance.";
      };

      extraSettings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Arbitrary connection-specific fields.";
      };
    };
  });
in
  sensible_option {
    forgejo-runner = mkOption {
      default = {};
      description = "Sensible Forgejo Actions runner daemon supporting multiple connections.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible Forgejo Actions runner";

          tokenEnvFile = mkOption {
            type = types.path;
            description = "Path to environment file containing KEY=TOKEN definitions matching connection names.";
          };

          connections = mkOption {
            type = types.attrsOf connectionSubmodule;
            default = {};
            description = "Declared Forgejo runner connections indexed by instance name.";
          };

          capacity = mkOption {
            type = types.ints.positive;
            default = 2;
            description = "Global maximum concurrent CI jobs across all connections.";
          };

          timeout = mkOption {
            type = types.str;
            default = "3h";
            description = "Maximum duration for an individual job execution.";
          };

          logLevel = mkOption {
            type = types.enum [
              "trace"
              "debug"
              "info"
              "warn"
              "error"
              "fatal"
            ];
            default = "info";
            description = "Daemon logging verbosity.";
          };

          insecure = mkOption {
            type = types.bool;
            default = false;
            description = "Global fallback for TLS verification.";
          };

          envFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path or filename to an environment file injected into CI workflows.";
          };

          cache = {
            enable = mkEnableOption "Runner built-in Actions cache server";
            dir = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Directory used to store cache files if enabled.";
            };
            host = mkOption {
              type = types.str;
              default = "";
              description = "Listen host address for the cache server.";
            };
            port = mkOption {
              type = types.port;
              default = 0;
              description = "Listen port for the cache server.";
            };
          };

          maxJobsPerBuild = mkOption {
            type = types.ints.positive;
            default = 2;
            description = "Nix daemon max-jobs setting injected into runner executions.";
          };

          coresPerJob = mkOption {
            type = types.ints.positive;
            default = 4;
            description = "Nix daemon cores setting injected into runner executions.";
          };

          buildTmpDir = mkOption {
            type = types.path;
            default = "/var/tmp/nix-build";
            description = "SSD-backed temporary build directory to avoid tmpfs RAM exhaustion.";
          };

          extraSettings = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Arbitrary top-level YAML keys recursively merged into the final runner config.";
          };
        };
      };
    };
  }
