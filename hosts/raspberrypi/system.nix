{
  config,
  pkgs,
  ...
}: let
  PHONE = 1000;
  TRUSTED = 900;
  TRAVELING = 200;
  EDUROAM = 0;
  networks = {
    "CindyPhone" = {
      priority = PHONE;
      pskRaw = "ext:PSK_CINDYPHONE";
    };
    "#ROOT > (BITS & BOSS)" = {
      pskRaw = "ext:PSK_ROOTRUMMET";
      priority = TRUSTED;
    };

    "Cinderblock_5G" = {
      pskRaw = "ext:PSK_CINDERBLOCK_5G";
      priority = TRUSTED;
    };
    "FamNilsson" = {
      priority = TRUSTED;
      pskRaw = "ext:PSK_FAMNILSSON";
    };
    "Barolo5" = {
      pskRaw = "ext:PSK_BAROLO";
      priority = TRUSTED;
    };
    "3MobilWiFi-4G-842A" = {
      pskRaw = "ext:PSK_MORFAR";
      priority = TRUSTED;
    };
    "Guest HvK/Skandion 5" = {
      pskRaw = "ext:PSK_GUEST_HVK";
      priority = TRAVELING;
    };
    "rbguest" = {
      priority = TRAVELING;
    };
    "SJ" = {
      priority = TRAVELING;
    };
    "snalltaget" = {
      priority = TRAVELING;
    };
    "Furusund Guest" = {
      priority = TRAVELING;
    };

    "Kalmarlanstrafik" = {
      priority = TRAVELING;
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
      priority = EDUROAM;
    };
  };
in {
  config.modules = {
    wifi = {
      enable = true;
      networks = networks;
    };
  };
}
