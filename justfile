set unstable := true
set dotenv-load := true
set positional-arguments := true
set shell := ["bash", "-uc"]

# Importera dynamiska host-recept om filen existerar
import? "hosts.justfile"

# --- Styling & Colors ---
export GUM_SPIN_SPINNER_FOREGROUND := "#D6B97F"
YELLOW := "\\033[1;33m"
RED    := "\\033[1;31m"
GREEN  := "\\033[1;32m"
BLUE   := "\\033[1;34m"
NORMAL := "\\033[0m"

# --- Konfiguration ---
flake_uri          := "."
user               := "root"
sensible_override  := env("SENSIBLE_OVERRIDE", "~/code_home/sensible-nix")
override_flag      := "--override-input sensible " + sensible_override
experimental_flags := "nix-command flakes pipe-operators"
default_device     := "/dev/sda"
jq                 := require("jq")

# --- Hjälpfunktioner ---
nix(action, flags) := "nix " + action + " " + override_flag + " --extra-experimental-features '" + experimental_flags + "' " + flags
nh(action, options, flags):= "nh os " + action + " " + flake_uri + " " + options + " -- " + override_flag + " " + flags
nix_attr(host, attr):= flake_uri + "#nixosConfigurations." + host + ".config." + attr

alias default := check

# ==============================================================================
# LOKAL DRIFT & KONTROLL
# ==============================================================================

[group("local")]
build *flags:
    {{ nh("switch", "", flags) }}

[group("local")]
boot *flags:
    {{ nh("boot", "", flags) }}

[group("local")]
check *flags:
    {{ nix("flake check", flags) }}

[group("local")]
update:
    {{ nix("flake update --flake " + flake_uri, "") }}

# ==============================================================================
# ARTEFAKTBYGGEN
# ==============================================================================

[group("building")]
build-sd host *flags:
    @echo -e "{{GREEN}}Bygger SD-avbild för {{ host }}...{{NORMAL}}"
    {{ nix("build", flags) }} {{ nix_attr(host, "system.build.sdImage") }} --show-trace

[group("building")]
build-netboot host *flags:
    @echo -e "{{GREEN}}Bygger netboot-artefakter för {{ host }}...{{NORMAL}}"
    {{ nix("build", flags) }} {{ nix_attr(host, "system.build.netboot-prebuilt") }} --show-trace

[group("building")]
build-iso host *flags:
    @echo -e "{{GREEN}}Bygger anpassad installations-ISO för {{ host }}...{{NORMAL}}"
    {{ nix("build", flags) }} {{ nix_attr(host, "system.build.isoImage") }} --show-trace

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

# Generera maskinens SSH host-nyckel och age-nyckel lokalt för sops-nix/ragenix bootstrap
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

# Provisionera en maskin som kör NixOS Minimal ISO med automatisk partitionering via Disko
[group("provisioning")]
bootstrap host ip *flags:
    @echo -e "{{GREEN}}Initierar bootstrap av {{ host }} på {{ ip }} (NixOS Minimal)...{{NORMAL}}"
    @if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no {{ user }}@{{ ip }} "true" 2>/dev/null; then \
        echo -e "{{RED}}Kunde inte nå {{ user }}@{{ ip }} via SSH. Säkerställ att maskinen körs och nätverket är uppe.{{NORMAL}}"; \
        exit 1; \
    fi
    nixos-anywhere \
        --flake {{ flake_uri }}#{{ host }} \
        --target-host {{ user }}@{{ ip }} \
        --build-on-remote \
        {{ flags }}

# Provisionera med Disko-partitionering samt automatisk injicering av SSH host-nycklar
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
    nixos-anywhere \
        --flake {{ flake_uri }}#{{ host }} \
        --target-host {{ user }}@{{ ip }} \
        --extra-files "$TEMP_DIR" \
        --build-on-remote

# Kexec-baserad netboot-provisionering för maskiner med befintligt OS eller minimal ISO
[group("provisioning")]
netboot-deploy host ip *flags: (build-netboot host)
    @echo -e "{{GREEN}}Deployar via kexec/netboot mot {{ ip }}...{{NORMAL}}"
    nixos-anywhere \
        --netboot-image result \
        --target-host {{ user }}@{{ ip }} \
        {{ flags }}

# Servera netboot-artefakter över nätverket för PXE-boot
[group("provisioning")]
netboot-serve host port="8080": (build-netboot host)
    @echo -e "{{GREEN}}Netboot-filer tillgängliga på port {{ port }}...{{NORMAL}}"
    cd result && python3 -m http.server {{ port }}

# ==============================================================================
# LÖPANDE DEPLOYMENT (SSH / WIREGUARD)
# ==============================================================================

# Deploya till en installerad maskin baserat på IP i WireGuard-konfigurationen
[group("deployment")]
deploy host *flags:
    @echo "Identifierar WireGuard-IP och uppdaterar: {{ host }}"
    @TARGET_IP=$({{ nix("eval", flake_uri + "#nixosConfigurations." + host + ".config.networking.wireguard.interfaces.wg0.ips --apply 'ips: builtins.head (builtins.split \"/\" (builtins.head ips))' --quiet --raw") }}); \
    {{ nh("switch", "--hostname " + host + " --target-host " + user + "@$TARGET_IP", flags) }}

# Deploya med godtycklig IP/hostname över SSH
[group("deployment")]
deploy-ip host ip *flags:
    @echo "Deployar till: {{ host }} via {{ ip }}"
    {{ nh("switch", "--hostname " + host + " --target-host " + user + "@" + ip, flags) }}

# Bygg och aktivera vid nästa omstart (användbart för kärnuppdateringar)
[group("deployment")]
deploy-boot-reboot host ip *flags:
    @echo "Bygger och sätter boot-profil för: {{ host }} via {{ ip }}"
    {{ nh("boot", "--hostname " + host + " --target-host " + user + "@" + ip, flags) }}
    @echo "Startar om {{ host }}..."
    ssh {{ user }}@{{ ip }} "systemctl reboot"

# ==============================================================================
# DYNAMISKA HOSTS & VERKTYG
# ==============================================================================

[group("tools")]
update-hosts:
    @{{ nix("eval", flake_uri + "#nixosConfigurations --apply 'builtins.attrNames' --json") }} | {{ jq }} -r '.[]' | \
    awk '{print $1 " *extra_flags:\n    @just deploy " $1 " {{ '{{' }}extra_flags{{ '}}' }}"}' > hosts.justfile
    @echo "hosts.justfile har uppdaterats."

[group("tools")]
clean-hosts:
    @echo "" > hosts.justfile

# --- Privata Recept ---

[private]
sync_filesystem:
    @gum spin --spinner pulse --title "Synkar filsystem..." -- sync
