{
  lib,
  modulesPath,
  config,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 67108864; # 64MB
    "net.core.wmem_max" = 67108864;
    "net.core.rmem_default" = 33554432; # 32MB
    "net.core.wmem_default" = 33554432;
    "net.core.netdev_max_backlog" = 10000;
  };
  # todo: remove this when this is fixed: https://github.com/NixOS/nixpkgs/issues/154163
  # related: https://github.com/NixOS/nixpkgs/issues/109280
  # related: https://discourse.nixos.org/t/cannot-build-raspberry-pi-sdimage-module-dw-hdmi-not-found/71804
  boot.initrd.allowMissingModules = true;
  boot.initrd.availableKernelModules = ["xhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];
  boot.kernelParams = ["cgroup_enable=memory" "cgroup_enable=cpuset" "cgroup_memory=1"];
  boot.zfs.forceImportRoot = false;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
