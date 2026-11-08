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
    mods = [
    "952940"  # https://www.curseforge.com/ark-survival-ascended/mods/stackable-prime-meats-x10 
    "937184"  # https://www.curseforge.com/ark-survival-ascended/mods/jvh-landscaping-mod
    "928824"  # https://www.curseforge.com/ark-survival-ascended/mods/moros-indomitable-duo
    "935528"  # https://www.curseforge.com/ark-survival-ascended/mods/visual-storage
    "1008253" # https://www.curseforge.com/ark-survival-ascended/mods/enhanced-spyglass
    ];
  };
  users.users.cindy.extraGroups = ["arkserver"];
}
