{pkgs, ...}: let
  networks = {
    "snalltaget" = {};
    "Cinderblock_5G" = {
      pskRaw = "ext:PSK_CINDERBLOCK_5G";
      priority = 0;
    };
    "Guest HvK/Skandion 5" = {
      pskRaw = "ext:PSK_GUEST_HVK";
    };
    "eduroam" = {
      auth = ''
        key_mgmt=WPA-EAP
        eap=PEAP
        pairwise=CCMP
        group=CCMP TKIP
        identity="dani24@eduroam.bth.se"
        password=ext:PSK_EDUROAM
        phase2="auth=MSCHAPV2"
      '';
      priority = 1;
    };
    "CindyPhone" = {
      priority = 2;
      pskRaw = "ext:PSK_CINDYPHONE";
    };
    "Dantes pixel" = {
      priority = 1;
      pskRaw = "ext:PSK_CINDYPHONE";
    };
    "rbguest" = {
      priority = 3;
    };
    "SJ" = {
      priority = 3;
    };
    "FamNilsson" = {
      priority = 0;
      pskRaw = "ext:PSK_FAMNILSSON";
    };
    "Barolo5" = {
      pskRaw = "ext:PSK_BAROLO";
    };
  };
in {
  config.modules = {
    declarative-password.enable = true;
    wifi = {
      enable = true;
      networks = networks;
    };
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
