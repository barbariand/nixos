{pkgs, ...}: {
  config.sensible = {
    podman.enable = false;
    steam = {
      enable = true;
      gamemode = true;
      extraPackages = [pkgs.mangohud pkgs.proton-ge-bin];
    };
    display-manager = {
      global_auto_login = true;
    };
    #plasma.enable=true;

    # gui
    hyprland = {
      enable = true;
      # monitors = [",highres,auto,1"];
    };

    monitors = ["eDP-1,1920x1080@60.00,auto,1"];
    live_wallpaper = {
      autostart = true;
      enable = true;
      default = "/home/cindy/wallpaper.mp4";
    };
    dunst.enable = false;
    swaync.enable = true;
    waybar.enable = true;
    browser = {
      default = "zen";
      zen.enable = true;
      chromium.enable = true;
    };
    # applets
    fuzzel.enable = true;
    discord = {
      enable = true;
      package = pkgs.vesktop;
      pname = "vesktop";
    };
    # cli
    shell = {
      fish.enable = true;
      default = "fish";
    };
    tmux.enable = true;
    # system
    xdg = {
      enable = true;
      defaultBrowser = "zen.desktop";
    };
  };
}
