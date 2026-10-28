set unstable := true
set dotenv-load := true
set shell := ["bash", "-uc"]

import? "hosts.justfile"

# --- Styling & Colors ---
export GUM_SPIN_SPINNER_FOREGROUND := "#D6B97F"
YELLOW := "\\033[1;33m"
RED    := "\\033[1;31m"
GREEN  := "\\033[1;32m"
BLUE   := "\\033[1;34m"
NORMAL := "\\033[0m"

# --- Konfiguration ---
flake_uri      := "."
user           := "root"
default_device := "/dev/sda"
jq             := require("jq")

# --- Smart Override Hantering ---
home          := env_var_or_default("HOME", "")
override_path := env_var_or_default("SENSIBLE_OVERRIDE", home + "/code_home/sensible-nix")
has_override  := path_exists(override_path)

override_flag := if has_override == "true" { "--override-input sensible " + override_path } else { "" }
nix_exp       := "--extra-experimental-features 'nix-command flakes pipe-operators'"
nix_flags     := nix_exp + " " + override_flag

anywhere_opts := if has_override == "true" { "--nix-options '" + override_flag + "'" } else { "" }
nh_opts       := if has_override == "true" { "-- " + override_flag } else { "" }

# --- Funktioner ---
nix(cmd, args) := "nix " + cmd + " " + nix_flags + " " + args
nh(cmd, args)  := "nh os " + cmd + " " + flake_uri + " " + args + " " + nh_opts
anywhere(host, ip, extra, args) := "nixos-anywhere --flake " + flake_uri + "#" + host + " --target-host " + user + "@" + ip + " " + extra + " " + anywhere_opts + " " + args

[group("local")]
default: check

# ==============================================================================
# LOKAL DRIFT & KONTROLL
# ==============================================================================

[group("local")]
check *args:
    {{ nix("flake check " + flake_uri, args) }}

[group("local")]
fmt:
    alejandra .

[group("local")]
switch *args:
    {{ nh("switch", args) }}

[group("local")]
boot *args:
    {{ nh("boot", args) }}

[group("local")]
update:
    {{ nix("flake update --flake " + flake_uri, "") }}

# ==============================================================================
# ARTEFAKTBYGGEN
# ==============================================================================

[group("building")]
build-sd host *args:
    @echo -e "{{GREEN}}Bygger SD-avbild för {{ host }}...{{NORMAL}}"
    {{ nix("build " + flake_uri + "#nixosConfigurations." + host + ".config.system.build.sdImage", "--show-trace " + args) }}

[group("building")]
build-netboot host *args:
    @echo -e "{{GREEN}}Bygger netboot-artefakter för {{ host }}...{{NORMAL}}"
    {{ nix("build " + flake_uri + "#nixosConfigurations." + host + ".config.system.build.netboot-prebuilt", "--show-trace " + args) }}

[group("building")]
build-iso host *args:
    @echo -e "{{GREEN}}Bygger anpassad installations-ISO för {{ host }}...{{NORMAL}}"
    {{ nix("build " + flake_uri + "#nixosConfigurations." + host + ".config.system.build.isoImage", "--show-trace " + args) }}

# ==============================================================================
# BARE-METAL / SD-KORT (OFFLINE-INSTALLATION)
# ==============================================================================

[group("hardware")]
flash-sd host device=default_device: (build-sd host)
    @if [ ! -b {{device}} ]; then echo -e "{{RED}}Fel: {{device}} är ingen blockenhet.{{NORMAL}}"; exit 1; fi
    @echo -e "{{YELLOW}}VARNING: All data på {{device}} kommer skrivas över!{{NORMAL}}"
    @gum confirm "Vill du skriva avbilden till {{device}}?"
    zstdcat result/sd-image/*.img.zst | sudo dd of={{device}} bs=4M iflag=fullblock conv=fsync status=progress
    just sync_filesystem

[group("hardware")]
mount-sd device=default_device:
    @mkdir -p mnt mnt2
    sudo mount {{device}}1 mnt
    sudo mount {{device}}2 mnt2
    @echo -e "{{GREEN}}Monterat: mnt (firmware/boot) och mnt2 (root){{NORMAL}}"

[group("hardware")]
unmount-sd:
    sudo umount mnt || true
    sudo umount mnt2 || true
    just sync_filesystem

[group("hardware")]
inject-secrets-sd device=default_device:
    just mount-sd {{device}}
    @echo -e "{{YELLOW}}Kopiera hemligheter till mnt/ eller mnt2/ nu.{{NORMAL}}"
    @gum confirm "Klar med injicering?"
    just unmount-sd

# ==============================================================================
# PROVISIONERING & INITIAL BOOTSTRAP (NIXOS-ANYWHERE)
# ==============================================================================

[group("provisioning")]
generate-host-keys host out_dir="secrets/hosts":
    @mkdir -p {{ out_dir }}/{{ host }}
    @if [ -f {{ out_dir }}/{{ host }}/ssh_host_ed25519_key ]; then \
        echo -e "{{YELLOW}}Nyckel finns redan för {{ host }} i {{ out_dir }}/{{ host }}. Avbryter.{{NORMAL}}"; \
        exit 0; \
    fi
    @echo -e "{{GREEN}}Genererar ny Ed25519 host-nyckel för {{ host }}...{{NORMAL}}"
    ssh-keygen -t ed25519 -f {{ out_dir }}/{{ host }}/ssh_host_ed25519_key -N "" -C "{{ host }}"
    @echo -e "{{BLUE}}Offentlig SSH-nyckel:{{NORMAL}}"
    @cat {{ out_dir }}/{{ host }}/ssh_host_ed25519_key.pub
    @echo -e "{{BLUE}}Age-mottagarnyckel för sops:{{NORMAL}}"
    @ssh-to-age < {{ out_dir }}/{{ host }}/ssh_host_ed25519_key.pub

[group("provisioning")]
bootstrap host ip *args:
    @echo -e "{{GREEN}}Initierar bootstrap av {{ host }} på {{ ip }} (NixOS Minimal)...{{NORMAL}}"
    @if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no {{ user }}@{{ ip }} "true" 2>/dev/null; then \
        echo -e "{{RED}}Kunde inte nå {{ user }}@{{ ip }} via SSH. Säkerställ att maskinen körs och nätverket är uppe.{{NORMAL}}"; \
        exit 1; \
    fi
    {{ anywhere(host, ip, "--build-on-remote", args) }}

[group("provisioning")]
bootstrap-with-secrets host ip secrets_dir="secrets/hosts":
    @echo -e "{{GREEN}}Förbereder hemligheter och bootstrap för {{ host }}...{{NORMAL}}"
    @TEMP_DIR=$(mktemp -d); \
    trap 'rm -rf "$TEMP_DIR"' EXIT; \
    mkdir -p "$TEMP_DIR/etc/ssh"; \
    if [ -f "{{ secrets_dir }}/{{ host }}/ssh_host_ed25519_key" ]; then \
        install -m 600 "{{ secrets_dir }}/{{ host }}/ssh_host_ed25519_key" "$TEMP_DIR/etc/ssh/ssh_host_ed25519_key"; \
        install -m 644 "{{ secrets_dir }}/{{ host }}/ssh_host_ed25519_key.pub" "$TEMP_DIR/etc/ssh/ssh_host_ed25519_key.pub"; \
    fi; \
    {{ anywhere(host, ip, "--extra-files $TEMP_DIR --build-on-remote", "") }}

[group("provisioning")]
netboot-deploy host ip *args: (build-netboot host)
    @echo -e "{{GREEN}}Deployar via kexec/netboot mot {{ ip }}...{{NORMAL}}"
    nixos-anywhere --netboot-image result --target-host {{ user }}@{{ ip }} {{ anywhere_opts }} {{ args }}

[group("provisioning")]
netboot-serve host port="8080": (build-netboot host)
    @echo -e "{{GREEN}}Netboot-filer tillgängliga på port {{ port }}...{{NORMAL}}"
    cd result && python3 -m http.server {{ port }}

# ==============================================================================
# LÖPANDE DEPLOYMENT (SSH / WIREGUARD)
# ==============================================================================

[group("deployment")]
deploy host *args:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{BLUE}}Söker anslutningsmål för {{ host }}...{{NORMAL}}"
    
    # Kör nix eval. Kastar stderr till /dev/null så det inte blöder igenom om attributet saknas,
    # och returnerar tomt (echo "") så att bash-variabeln blir korrekt tom om kommandot felar.
    TARGET_IP=$({{ nix("eval", flake_uri + "#nixosConfigurations." + host + ".config.sensible.wireguard.wg0.topology.nodes." + host + ".ip --quiet --raw") }} 2>/dev/null || echo "")

    if [ -z "$TARGET_IP" ]; then
        echo -e "{{YELLOW}}Ingen WireGuard-IP hittades"
        exit
    fi

    echo -e "{{GREEN}}Uppdaterar {{ host }} via ${TARGET_IP}...{{NORMAL}}"
    {{ nh("switch", "--hostname " + host + " --target-host " + user + "@${TARGET_IP} " + args) }}

[group("deployment")]
deploy-ip host ip *args:
    @echo "Deployar till: {{ host }} via {{ ip }}"
    {{ nh("switch", "--hostname " + host + " --target-host " + user + "@" + ip + " " + args) }}

[group("deployment")]
deploy-boot-reboot host ip *args:
    @echo "Bygger och sätter boot-profil för: {{ host }} via {{ ip }}"
    {{ nh("boot", "--hostname " + host + " --target-host " + user + "@" + ip + " " + args) }}
    @echo "Startar om {{ host }}..."
    ssh {{ user }}@{{ ip }} "systemctl reboot"

# ==============================================================================
# DYNAMISKA HOSTS & VERKTYG
# ==============================================================================

[group("tools")]
update-hosts:
    {{ nix("eval", flake_uri + "#nixosConfigurations --apply 'builtins.attrNames' --json") }} | {{ jq }} -r '.[]' | \
    awk '{print $1 " *args:\n    @just deploy " $1 " {{ '{{' }}args{{ '}}' }}"}' > hosts.justfile
    @echo "hosts.justfile har uppdaterats."

[group("tools")]
clean-hosts:
    @echo "" > hosts.justfile

# --- Privata Recept ---

[private]
sync_filesystem:
    @gum spin --spinner pulse --title "Synkar filsystem..." -- sync
