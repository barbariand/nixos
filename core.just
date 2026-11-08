DEFAULT_DEVICE := env_var_or_default("DEFAULT_DEVICE", "/dev/sda")

[group("core-general")]
default:
    @just --list core

[group("core-deployment")]
deploy host *args:
    @./scripts/deploy.sh switch {{ host }} {{ args }}

[group("core-deployment")]
boot host *args:
    @./scripts/deploy.sh boot {{ host }} {{ args }}

[group("core-build")]
build-sd host *args:
    @./scripts/build.sh sd {{ host }} {{ args }}

[group("core-build")]
build-netboot host *args:
    @./scripts/build.sh netboot {{ host }} {{ args }}

[group("core-build")]
build-iso host *args:
    @./scripts/build.sh iso {{ host }} {{ args }}

[group("core-access")]
ssh host *args:
    @./scripts/ssh.sh {{ host }} ssh {{ args }}

[group("core-access")]
reboot host:
    @./scripts/ssh.sh {{ host }} reboot

[group("core-hardware")]
flash-sd host device=DEFAULT_DEVICE: (build-sd host)
    @./scripts/hardware.sh flash {{ host }} {{ device }}

[group("core-hardware")]
mount-sd device=DEFAULT_DEVICE:
    @./scripts/hardware.sh mount {{ device }}

[group("core-hardware")]
unmount-sd:
    @./scripts/hardware.sh unmount

[group("core-hardware")]
inject-secrets-sd device=DEFAULT_DEVICE:
    @./scripts/hardware.sh inject {{ device }}

[group("core-provisioning")]
generate-keys host out_dir="secrets/hosts":
    @./scripts/provision.sh generate-keys {{ host }} {{ out_dir }}

[group("core-provisioning")]
bootstrap host ip *args:
    @./scripts/provision.sh bootstrap {{ host }} {{ ip }} {{ args }}

[group("core-provisioning")]
bootstrap-secrets host ip secrets_dir="secrets/hosts":
    @./scripts/provision.sh bootstrap-secrets {{ host }} {{ ip }} {{ secrets_dir }}
