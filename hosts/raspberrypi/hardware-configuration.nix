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

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = "/etc/secrets/cloudflare-token";
    domains = ["simd.me"];
  };
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = ["0.0.0.0"];
        access-control = ["192.168.1.0/24 allow"];
        # This is the "Split-DNS" magic
        local-zone = ''"simd.me." static'';
        local-data = ''"simd.me. IN A 192.168.1.3"'';
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = ["1.1.1.1" "8.8.8.8"];
        }
      ];
    };
  };

  # Open DNS port 53 on the Pi's firewall
  networking.firewall.allowedUDPPorts = [
    51820 # WireGuard
    53 # DNS/Unbound
  ];
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
