{
  config,
  pkgs,
  ...
}: let
  networks = {
    "Cinderblock_5G" = {
      psk = "@PSK_CINDERBLOCK@";
      priority = 0;
    };
  };
in {
  config.modules = {
    wifi = {
      enable = true;
      networks = networks;
    };
    # Aktivera podman för att agera som "delegator" (proxmox-ish för containrar)
    podman.enable = true;
  };

  # Syncthing-konfiguration
  services.syncthing = {
    enable = true;
    user = "cindy";
    dataDir = "/home/cindy/syncthing";
    configDir = "/home/cindy/.config/syncthing";
    guiAddress = "0.0.0.0:8384"; # Tillåt åtkomst från nätverket
  };

  # Cloudflare Dynamic DNS
  # Kräver att API-nyckeln finns i en fil för att undvika exponering i nix-store
  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = "/etc/secrets/cloudflare-token"; # Skapa denna fil manuellt eller via agenix
    domains = ["din-doman.me"];
  };

  # Grundläggande inställningar för Raspberry Pi
  boot.loader.raspberryPi.enable = true;
  boot.loader.raspberryPi.version = 4;
  hardware.raspberry-pi."4".apply-overlays-dtmerge = true;

  # GPU-minne för en server-ish setup (kan hållas lågt om ingen skärm används)
  hardware.raspberry-pi."4".gpu-mem = 16;
}
