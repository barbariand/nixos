{
  config,
  pkgs,
  ...
}: {
  services.ark-server = {
    enable = true;

    sessionName = "Cindy's Ark World";
    adminPassword = "ditt-hemliga-lösenord";
    multiHome = "192.168.1.4";
    map = "TheIsland_WP";
    publicDomain = "ark.simd.me";
    mods = "952945";
  };
  networking.hosts = {
    "192.168.1.4" = [config.networking.hostName];
  };
}
