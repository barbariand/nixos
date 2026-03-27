{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    # Auto-generated hardware detection
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["i2c-dev"];
  boot.extraModulePackages = [];

  boot.initrd = {
    includeDefaultModules = false;
    availableKernelModules = lib.mkForce [
      "usbhid"
      "usb_storage"
      "vc4"
      "pcie_brcmstb"
      "reset_raspberrypi"
      "genet"
    ];
    network.ssh.enable = true;
    network.ssh.port = 22;
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = "/etc/secrets/cloudflare-token";
    domains = ["simd.me"];
  };
}
