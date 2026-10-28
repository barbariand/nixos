{
  config,
  pkgs,
  ...
}: {
  sensible.ark-server = {
    enable = true;
    autoUpdate = true;
    sessionName = "Cindy's Ark World";
    adminPassword = "ditt-hemliga-lösenord";
    #multiHome = "192.168.1.5";
    map = "TheIsland_WP";
    publicDomain = "ark.simd.me";
    mods = "952945";
  };
}
