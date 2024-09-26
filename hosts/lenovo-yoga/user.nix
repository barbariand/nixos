{...}: {
  config.modules = {
    # gui
    hyprland = {
      enable = true;
      monitors = ["eDP-1,1920x1200@59.99900,0x0,1"];
    };
    eww.enable = true;
    waybar.enable = false;
    dunst.enable = false;

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
    xdg.enable = true;
    gtk.enable = true;
    packages.enable = true;
  };
}
