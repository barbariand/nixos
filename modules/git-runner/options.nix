{
  lib,
  sensible_option,
  ...
}:
with lib; let
  defaultLabels = [
    "nixos:host"
    "nix:host"
    "linux-x86_64:host"
  ];

  forgejoRunnerSubmodule = types.submodule ({name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this specific Forgejo runner connection is enabled.";
      };

      name = mkOption {
        type = types.str;
        default = name;
        description = "Internal/display name of the runner (defaults to the attribute key).";
      };

      url = mkOption {
        type = types.str;
        example = "https://git.urgobalt.dev";
        description = "Forgejo instance URL.";
      };

      uuid = mkOption {
        type = types.str;
        description = "Pre-registered runner UUID for this Forgejo instance.";
      };

      labels = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Per-runner job labels (falls back to forgejo.labels, then git_runner.labels).";
      };

      insecure = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Allow insecure TLS connection to this specific instance (falls back to forgejo.insecure).";
      };

      extraSettings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Arbitrary Forgejo connection-specific YAML fields.";
      };
    };
  });

  githubRunnerSubmodule = types.submodule ({name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this specific GitHub Actions runner service is enabled.";
      };

      name = mkOption {
        type = types.str;
        default = name;
        description = "Runner name registered in GitHub (defaults to the attribute key).";
      };

      url = mkOption {
        type = types.str;
        example = "https://github.com/Barbariand11 or https://github.com/org/repo";
        description = "GitHub repository, organization, or enterprise URL.";
      };

      tokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing the GitHub runner registration token or PAT (falls back to github.tokenFile).";
      };

      labels = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Per-runner job labels (falls back to github.labels, then git_runner.labels; ':host' is stripped automatically).";
      };

      ephemeral = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Unregister the runner after executing a single job (falls back to github.ephemeral).";
      };

      replace = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Replace any existing runner with the same name on startup (falls back to github.replace).";
      };

      runnerGroup = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional GitHub organization/enterprise runner group (falls back to github.runnerGroup).";
      };

      extraSettings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Extra options merged directly into services.github-runners.<name>.";
      };
    };
  });
in
  sensible_option {
    git_runner = mkOption {
      default = {};
      description = "Unified multi-forge CI runner daemon supporting Forgejo Actions and GitHub Actions.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible multi-forge Git CI runners";

          labels = mkOption {
            type = types.listOf types.str;
            default = defaultLabels;
            description = "Global default job labels inherited by all backends and runners unless overridden.";
          };

          envFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to an environment file injected into CI workflows across all runners.";
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

          priority = {
            cpuWeight = mkOption {
              type = types.ints.positive;
              default = 50;
              description = "Systemd CPUWeight for runner cgroups.";
            };

            ioWeight = mkOption {
              type = types.ints.positive;
              default = 50;
              description = "Systemd IOWeight for runner cgroups.";
            };

            oomScoreAdjust = mkOption {
              type = types.ints.between (-1000) 1000;
              default = 500;
              description = "Systemd OOMScoreAdjust for runner daemons.";
            };
          };

          # --- Forgejo backend (delade inställningar + runners) ---
          forgejo = mkOption {
            default = {};
            description = "Forgejo Actions runner configuration and runner connections.";
            type = types.submodule {
              options = {
                tokenEnvFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to environment file containing KEY=TOKEN definitions matching forgejo.runners keys.";
                };

                labels = mkOption {
                  type = types.nullOr (types.listOf types.str);
                  default = null;
                  description = "Default labels for all Forgejo runners (falls back to git_runner.labels).";
                };

                capacity = mkOption {
                  type = types.ints.positive;
                  default = 2;
                  description = "Global maximum concurrent CI jobs across all Forgejo connections.";
                };

                timeout = mkOption {
                  type = types.str;
                  default = "3h";
                  description = "Maximum duration for an individual Forgejo job execution.";
                };

                fetchInterval = mkOption {
                  type = types.str;
                  default = "10s";
                  description = "Polling interval for fetching tasks and retry cadence when upstream is unreachable.";
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
                  description = "Forgejo daemon logging verbosity.";
                };

                insecure = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Default TLS verification skip setting across Forgejo connections.";
                };

                cache = {
                  enable = mkEnableOption "Forgejo runner built-in Actions cache server";
                  dir = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                  };
                  host = mkOption {
                    type = types.str;
                    default = "";
                  };
                  port = mkOption {
                    type = types.port;
                    default = 0;
                  };
                };

                extraSettings = mkOption {
                  type = types.attrsOf types.anything;
                  default = {};
                  description = "Arbitrary top-level YAML keys recursively merged into the Forgejo runner config.";
                };

                runners = mkOption {
                  type = types.attrsOf forgejoRunnerSubmodule;
                  default = {};
                  description = "Declared Forgejo runner connections indexed by instance identifier.";
                };
              };
            };
          };

          # --- GitHub backend (delade inställningar + runners) ---
          github = mkOption {
            default = {};
            description = "GitHub Actions runner configuration and runner instances.";
            type = types.submodule {
              options = {
                tokenFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Default path to GitHub registration token or PAT file shared across GitHub runners.";
                };

                labels = mkOption {
                  type = types.nullOr (types.listOf types.str);
                  default = null;
                  description = "Default labels for all GitHub runners (falls back to git_runner.labels; ':host' is stripped).";
                };

                ephemeral = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Default ephemeral setting for all GitHub runners.";
                };

                replace = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Default replace setting for all GitHub runners.";
                };

                runnerGroup = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Default GitHub organization/enterprise runner group for all GitHub runners.";
                };

                extraSettings = mkOption {
                  type = types.attrsOf types.anything;
                  default = {};
                  description = "Shared overrides merged into every services.github-runners.<name> definition.";
                };

                runners = mkOption {
                  type = types.attrsOf githubRunnerSubmodule;
                  default = {};
                  description = "Declared GitHub Actions runners indexed by runner identifier.";
                };
              };
            };
          };
        };
      };
    };
  }
