{pkgs, ...}: {
  config.modules = {
    # gui
    hyprland = {
      live_wallpaper = {
        auto_start = true;
        enable = true;
        default = "~/wallpaper.mp4";
        monitors = ["DP-2" "HDMI-A-1"];
      };
      enable = true;
      monitors = ["DP-2,1920x1080@60.00,0x0,0.5" "HDMI-A-1,1920x1080@60.00,3840x960,1"];
      # monitors = [",highres,auto,1"];
      browser = pkgs.zen-browser;
    };
    dunst.enable = false;
    swaync.enable = true;
    waybar.enable = true;
    zen.enable = true;
    ghostty.enable = true;
    # applets
    fuzzel.enable = true;
    chromium.enable = true;
    social.enable = true;

    # cli
    nvim.enable = true;
    fish.enable = true;
    git.enable = true;
    pass.enable = true;
    tmux.enable = true;
    # system
    xdg = {
      enable = true;
      defaultBrowser = "zen.desktop";
    };
    gtk.enable = true;
    packages.enable = true;
  };
}
