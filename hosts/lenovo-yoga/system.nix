let
  networks = {
    "Cinderblock_5G" = {
      psk = "@PSK_CINDERBLOCK@";
      priority = 0;
    };
    "eduroam" = {
      auth = ''
        key_mgmt=WPA-EAP
        eap=PEAP
        identity="@ID_EDUROAM@"
        password="@PSK_EDUROAM@"
        phase2="auth=MSCHAPV2"
      '';
      priority = 2;
    };
    "CindyPhone" = {
      priority = 1;
      psk = "@PSK_CINDYPHONE@";
    };
    "rbguest" = {
      priority = 3;
    };
    "SJ" = {
      priority = 3;
    };
    "FamNilsson" = {
      priority = 0;
      psk = "@PSK_FAMNILSSON@";
    };
    "Barolo5" = {
      psk = "@PSK_BAROLO@";
    };
 };
in {
  config.modules = {
    wifi = {
      enable = true;
      networks = networks;
    };

    display-manager.enable = true;
    #plasma.enable=true;
  };
}
