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

  # todo: remove this when this is fixed: https://github.com/NixOS/nixpkgs/issues/154163
  # related: https://github.com/NixOS/nixpkgs/issues/109280
  # related: https://discourse.nixos.org/t/cannot-build-raspberry-pi-sdimage-module-dw-hdmi-not-found/71804
  boot.initrd.allowMissingModules = true;
  boot.initrd.availableKernelModules = ["xhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];
  boot.kernelParams = ["cgroup_enable=memory" "cgroup_enable=cpuset" "cgroup_memory=1"];


  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
