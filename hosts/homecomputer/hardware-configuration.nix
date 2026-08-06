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

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "sr_mod"
      ];
      kernelModules = [];
    };

    kernelModules = [
      "kvm-amd"
      "xone-dongle"
    ];

    kernelParams = [
      "nvidia-drm.modeset=1"
      "usbcore.autosuspend=-1"
    ];

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = true;
      tmpfsSize = "50%";
    };

    binfmt.emulatedSystems = ["aarch64-linux"];
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    xone.enable = true;
    xpadneo.enable = true;
  };

  # Tjänster & Drivrutiner
  services = {
    xserver = {
      videoDrivers = ["nvidia"];
      digimend.enable = true;
    };
    tailscale.enable = true;
  };

  # Nätverk & Wake-on-LAN
  networking.useDHCP = lib.mkDefault true;

  systemd.network.links."10-wol" = {
    matchConfig.Name = "enp7s0";
    linkConfig.WakeOnLan = "magic";
  };

  systemd.services.set-wol = {
    description = "Configure Wake-on-LAN for enp7s0";
    after = ["network-pre.target"];
    wants = ["network-pre.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s enp7s0 wol g";
    };
  };

  # Miljövariabler
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    NVD_BACKEND = "direct";
    __GL_SHADER_DISK_CACHE_SIZE = "12000000000";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
