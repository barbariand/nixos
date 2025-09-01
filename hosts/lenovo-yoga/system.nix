let
  networks = {
    "CindyPhone" = {
      priority = 0;
      pskRaw = "ext:PSK_CINDYPHONE";
    };
    "Dantes pixel" = {
      priority = 0;
      pskRaw = "ext:PSK_CINDYPHONE";
    };
    "Cinderblock_5G" = {
      pskRaw = "ext:PSK_CINDERBLOCK_5G";
      priority = 1;
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
    "FamNilsson" = {
      priority = 2;
      pskRaw = "ext:PSK_FAMNILSSON";
    };
    "Barolo5" = {
      pskRaw = "ext:PSK_BAROLO";
      priority = 2;
    };
    "3MobilWiFi-4G-842A" = {
      pskRaw="ext:PSK_MORFAR";
      priority = 2;
    };
    "Guest HvK/Skandion 5" = {
      pskRaw = "ext:PSK_GUEST_HVK";
      priority = 3;
    };
    "rbguest" = {
      priority = 3;
    };
    "SJ" = {
      priority = 3;
    };
    "snalltaget" = {
      priority = 3;
    };
    "Furusund Guest" = {
      priority = 3;
    };
  };
in {
  config.modules = {
    declarative-password.enable = true;
    wifi = {
      enable = true;
      networks = networks;
    };
    steam = {enable = true;};
    display-manager = {
      enable = true;
    };
    #plasma.enable=true;
  };
}
