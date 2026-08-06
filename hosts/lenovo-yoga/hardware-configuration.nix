{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd" "amdgpu"];
  services.upower.enable = true;
  boot.loader.grub.splashImage = ./../../background.jpg;

  # Zen-kärnan ger lägre latens och innehåller fsync-patchar för Proton/Wine
  boot.kernelPackages = pkgs.linuxPackages_zen;

  hardware.xpadneo.enable = true;
  hardware.xone.enable = true;
  services.udev.packages = [pkgs.game-devices-udev-rules];

  boot.kernelParams = [
    "usbcore.autosuspend=-1"
    # Förhindrar prestandafall vid split-lock instruktioner i Proton/Wine
    "split_lock_detect=off"
    # Låser upp hela PowerPlay-gränssnittet för AMDGPU (överklockning/undervoltning)
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Använd standard Mesa för RADV Vulkan-drivrutinen; amdgpu-pro krävs ej för spel
    extraPackages = with pkgs; [
      rocmPackages.clr.icd 
    ];
  };

  # Tillåt användare i gamemode/users-gruppen att ändra processprioritet
  security.pam.loginLimits = [
    {
      domain = "@users";
      item = "nice";
      type = "-";
      value = "-20";
    }
  ];

  zramSwap.enable = true;
  zramSwap.priority = 100;
  zramSwap.memoryPercent = 50;

  swapDevices = [
    {device = "/dev/disk/by-uuid/3a0d3bbd-adce-48e8-ab46-dc0083044b2b";}
    {
      device = "/var/lib/swapfile";
      size = 16384;
      priority = 5;
    }
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    # Stäng av split lock mitigation i kärnan helt för att kapa latensspikar
    "kernel.split_lock_mitigate" = 0;
  };

  # Sätt CPU till performance-läge om du vill köra maxfrekvens permanent
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  services.udev.extraRules = ''
    # wierd xpad fix
    SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="6013", MODE="0660", GROUP="users"
    KERNEL=="ttyACM0", MODE="0777"
  '';

  services.avahi.enable = true;
}
