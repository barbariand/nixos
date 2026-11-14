{
  cfg,
  config,
  lib,
  pkgs,
}: let
  atticBootstrapScript = pkgs.writeShellScript "attic-bootstrap" ''
    set -euo pipefail
    export HOME="/run/atticd-bootstrap"
    export XDG_CONFIG_HOME="/run/atticd-bootstrap/.config"

    mkdir -p "$XDG_CONFIG_HOME/attic"

    for _ in $(seq 1 30); do
      if ${pkgs.curl}/bin/curl -sf "http://127.0.0.1:${toString cfg.port}/" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    # Extrahera konfigurationsfilen robust från systemd
    ATTIC_ENV=$(${pkgs.systemd}/bin/systemctl show atticd.service --property=Environment)
    ATTIC_CONF=$(echo "$ATTIC_ENV" | ${pkgs.coreutils}/bin/tr ' ' '\n' | ${pkgs.gnugrep}/bin/grep '^ATTIC_SERVER_CONFIG=' | ${pkgs.coreutils}/bin/cut -d= -f2 || true)

    if [ -z "$ATTIC_CONF" ]; then
      ATTIC_CONF=$(${pkgs.systemd}/bin/systemctl cat atticd.service | ${pkgs.gnugrep}/bin/grep -o '\-f /nix/store/[^ ]*' | ${pkgs.coreutils}/bin/cut -d' ' -f2 | ${pkgs.coreutils}/bin/head -n 1 || true)
    fi

    if [ -z "$ATTIC_CONF" ]; then
      echo "ERROR: Kunde inte hitta atticd konfigurationsfilen från systemd!" >&2
      exit 1
    fi

    TOKEN=$(${config.services.atticd.package}/bin/atticadm -f "$ATTIC_CONF" make-token \
      --sub "local-bootstrap" \
      --validity "10m" \
      --pull "${cfg.cacheName}" \
      --push "${cfg.cacheName}" \
      --create-cache "${cfg.cacheName}" \
      --configure-cache "${cfg.cacheName}" \
      --configure-cache-retention "${cfg.cacheName}")

    ${pkgs.attic-client}/bin/attic login local "http://127.0.0.1:${toString cfg.port}" "$TOKEN"

    if ! ${pkgs.attic-client}/bin/attic cache info "local:${cfg.cacheName}" >/dev/null 2>&1; then
      ${pkgs.attic-client}/bin/attic cache create "local:${cfg.cacheName}" ${lib.optionalString cfg.publicPull "--public"}
    fi

    ${pkgs.attic-client}/bin/attic cache configure "local:${cfg.cacheName}" \
      ${
      if cfg.publicPull
      then "--public"
      else "--private"
    } \
      --retention-period "${cfg.garbageCollection.defaultRetentionPeriod}"

    ${pkgs.attic-client}/bin/attic cache info "local:${cfg.cacheName}" > $HOME/${cfg.cacheName}-cache-info.txt
  '';
in {
  systemd.services.atticd-bootstrap = {
    description = "Declaratively Bootstrap Attic Cache (Public Pull / Private Push)";
    after = [
      "atticd.service"
      "postgresql.service"
    ];
    requires = ["atticd.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "atticd";
      Group = "atticd";
      EnvironmentFile = cfg.environmentFile;
      RuntimeDirectory = "atticd-bootstrap";
      RuntimeDirectoryMode = "0700";
      ExecStart = atticBootstrapScript;
    };
  };
}
