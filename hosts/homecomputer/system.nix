{pkgs, ...}: {
  config.sensible = {
    wireguard."wg0".enable = true;
    # gui
    hyprland = {
      configOpt = {
        render = {
          direct_scanout = 0;
        };
      };
      enable = true;
      debug = true; # Förhindrar att disable_logs sätts till true
    };
    launcher = "walker";
    steam = {
      enable = true;
      extraPackages = with pkgs; [gamescope gamemode mangohud proton-ge-bin];
    };

    display-manager = {
      global_auto_login = true;
    };

    monitors = ["HDMI-A-1,3840x2160@30.00,0x0,1" "DP-2,1920x1080@60.00,3840x1088,1"];
    live_wallpaper = {
      autostart = true;
      enable = true;
      default = "/home/cindy/wallpaper.mp4";
    };

    swaync.enable = true;
    waybar.enable = true;
    browser = {
      default = "zen";
      zen.enable = true;
      chromium.enable = true;
    };

    fuzzel.enable = true;
    discord = {
      enable = true;
      package = pkgs.vesktop;
      package-class = "vesktop";
    };

    podman.enable = false;
    # system
    xdg = {
      enable = true;
      defaultBrowser = "zen.desktop";
    };
  };
}
