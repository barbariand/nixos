{pkgs, ...}: {
  config.modules = {
    declarative-password.enable = true;

    podman.enable = false;
    steam = {
      enable = true;
      gamemode = true;
      extraPackages = [pkgs.mangohud pkgs.proton-ge-bin];
    };
    display-manager = {
      enable = true;
      monitors = ["HDMI-A-1,3840x2160@30.00,0x0,1" "DP-2,1920x1080@60.00,3840x1088,1"];
    };
    #plasma.enable=true;
  };
}
