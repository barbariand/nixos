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

  boot.initrd.availableKernelModules = ["xhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];
  boot.kernelParams = ["cgroup_enable=memory" "cgroup_enable=cpuset" "cgroup_memory=1"];

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = "/etc/secrets/cloudflare-token";
    domains = ["simd.me"];
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
