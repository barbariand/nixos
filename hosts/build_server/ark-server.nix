{
  config,
  user,
  ...
}: {
  sensible.ark-server = {
    enable = true;
    autoUpdate = true;
    sessionName = "Cindy's Ark World";
    adminPasswordFile = config.age.secrets.ark-admin-password.path;
    map = "TheIsland_WP";
    publicDomain = "ark.simd.me";

    serviceConfig = {
      AllowedCPUs = "0,1,6,7";
      CPUWeight = 500;
      IOWeight = 500;
      OOMScoreAdjust = -500;
      Nice = -10;
    };

    mods = [
      "931874" # https://www.curseforge.com/ark-survival-ascended/mods/arkitect-structures-remastered
      "957616" # https://www.curseforge.com/ark-survival-ascended/mods/more-plants
      "946694" # https://www.curseforge.com/ark-survival-ascended/mods/klinger-additional-rustic-building
      "952940" # https://www.curseforge.com/ark-survival-ascended/mods/stackable-prime-meats-x10
      "937184" # https://www.curseforge.com/ark-survival-ascended/mods/jvh-landscaping-mod
      "928824" # https://www.curseforge.com/ark-survival-ascended/mods/moros-indomitable-duo
      "935528" # https://www.curseforge.com/ark-survival-ascended/mods/visual-storage
      "1008253" # https://www.curseforge.com/ark-survival-ascended/mods/enhanced-spyglass
    ];
  };
  users.users.${user}.extraGroups = ["arkserver"];
}
