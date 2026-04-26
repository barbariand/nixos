{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  # programs.steam.gamescopeSession = {
  #  enable = true;
  #};
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
  boot.kernelParams = ["nvidia-drm.modeset=1" "usbcore.autosuspend=-1"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd" "xone-dongle"];
  hardware.enableRedistributableFirmware = true;

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  boot.loader.efi.canTouchEfiVariables = true;
  hardware.xone.enable = true;
  hardware.xpadneo.enable = true;
  boot.loader.systemd-boot.enable = true;
  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    # For some newer Nvidia drivers, this might also be needed for Xwayland
    NVD_BACKEND = "direct";
    # If you experience flickering or issues with Xwayland later, you might also try:
    # WLR_RENDERER_ALLOW_SOFTWARE = "0"; # to prevent fallback to llvmpipe
    # __GL_GSYNC_ALLOWED = "0"; # if not using G-Sync
    # __GL_VRR_ALLOWED = "0"; # if not using VRR
  };
  swapDevices = [];
  services.xserver.digimend.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  services.tailscale.enable = true;

# networking.firewall.allowedUDPPorts = [
#   # Wireguard
#   51820
#   # ARK Game & Query portar
#   7777 7778 27015
#   25147 27031 27032 27033 27034 27035 27036
# ];
# networking.firewall.allowedTCPPorts = [
#   22 # SSH
#   25147 27015 27036 # ARK server
# ];
#   services.xserver.videoDrivers = ["nvidia"];
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp7s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.vmnet1.useDHCP = lib.mkDefault true;
  # networking.interfaces.vmnet8.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
