{pkgs, ...}: {
  config.sensible = {
    # gui
    hyprland.enable = true;
    launcher = "walker";
    podman.enable = false;
    starship.enable = true;
    direnv.enable = true;
    zoxide.enable = true;
    steam = {
      enable = true;
      gamemode = true;
      extraPackages = [pkgs.mangohud pkgs.proton-ge-bin];
    };
    display-manager = {
      global_auto_login = true;
    };
    #plasma.enable=true;

    monitors = ["eDP-1,highres,auto,1"];
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
      package-class = "vesktop";
    };
    terminal.default ="kitty";
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
