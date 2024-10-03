{...}: {
  config.modules = {
    # gui
    hyprland = {
      enable = true;
      monitors = ["eDP-1,1920x1200@59.99900,0x0,1"];
    };
    dunst.enable=true;
    eww.enable = true;
    waybar.enable = false;
    zen.enable=true;
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
    xdg={enable = true; defaultBrowser="zen.desktop";};
    gtk.enable = true;
    packages.enable = true;
  };
}
