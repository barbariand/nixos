{
lib,
  sensible_option,
  ...
}:
with lib;
sensible_option {
  forgejo-runner = mkOption {
    default = {};
    description = "Sensible Forgejo Actions runner in host execution mode.";
    type = types.submodule {
      options = {
        enable = mkEnableOption "Sensible Forgejo Actions runner";

        name = mkOption {
          type = types.str;
          default = "build-server-nix";
        };

        url = mkOption {
          type = types.str;
          default = "https://git.urgobalt.dev";
          description = "Forgejo instance URL.";
        };

        tokenFile = mkOption {
          type = types.path;
          description = "Path to secret file containing TOKEN=<runner_registration_token>.";
        };

        capacity = mkOption {
          type = types.ints.positive;
          default = 2;
          description = "Max concurrent CI jobs.";
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
          description = "SSD-backed temporary build directory to prevent RAM tmpfs exhaustion.";
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
    };
  };
}
