{pkgs, ...}: {
  config.modules = {
    declarative-password.enable = false;
    steam = {
      enable = true;
      gamemode = true;
      extraPackages = [pkgs.mangohud pkgs.proton-ge-bin];
    };
    display-manager = {
      enable = true;
      monitors = ["DP-2,1920x1080@60.00,0x0,0.5" "HDMI-A-1,1920x1080@60.00,3840x960,1"];
    };
    #plasma.enable=true;
  };
}
