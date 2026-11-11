{
  cfg,
  lib,
  pkgs,
  pConfig,
}:
with lib; let
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
    nodejs
    openssh
    xz
    yq-go
    zstd
  ];
in {
  users.users.forgejo-runner = {
    isSystemUser = true;
    group = "forgejo-runner";
    home = "/var/lib/forgejo-runner";
    createHome = true;
  };
  users.groups.forgejo-runner = {};

  systemd.services.forgejo-runner-ci = {
    description = "Forgejo Actions Runner CI";
    after = [
      "network-online.target"
      "nix-daemon.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    path = hostPackages;

    environment = {
      TMPDIR = toString cfg.buildTmpDir;
      NIX_CONFIG = ''
        experimental-features = nix-command flakes pipe-operators
        max-jobs = ${toString cfg.maxJobsPerBuild}
        cores = ${toString cfg.coresPerJob}
      '';
    };

    serviceConfig = {
      User = "forgejo-runner";
      Group = "forgejo-runner";
      DynamicUser = false;
      StateDirectory = "forgejo-runner";
      RuntimeDirectory = "forgejo-runner";
      RuntimeDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/forgejo-runner";

      CPUWeight = cfg.priority.cpuWeight;
      IOWeight = cfg.priority.ioWeight;
      MemoryHigh = "10G";
      MemoryMax = "12G";
      OOMScoreAdjust = cfg.priority.oomScoreAdjust;
      Restart = "always";
      RestartSec = "10s";

      ExecStartPre = pkgs.writeShellScript "forgejo-runner-build-config" ''
        set -euo pipefail

        CONFIG_DEST="/run/forgejo-runner/config.yaml"
        cp "${pConfig.baseConfigFile}" "$CONFIG_DEST"
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
        done < "${cfg.tokenEnvFile}"
      '';

      ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner daemon --config /run/forgejo-runner/config.yaml";
    };
  };
}
