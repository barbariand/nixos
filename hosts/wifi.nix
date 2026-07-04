{matchInterfaces ? "wlp* wlan*"}: {config, ...}: let
  PHONE = 1000;
  EDUROAM = 950;
  TRUSTED = 900;
  TRAVELING = 200;
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
    "#Telia-3C92E0" = {
      pskRaw = "ext:PSK_ANDERS";
      priority = TRUSTED;
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
  age.secrets.wifi-env = {
    mode = "0440";
    group = "wpa_supplicant";
  };
  networking.networkmanager.enable = false;
  networking.wireless = {
    enable = true;
    userControlled = true;
    secretsFile = config.age.secrets.wifi-env.path;
    networks = networks;
  };
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;
    networks."25-wireless" = {
      matchConfig.Name = matchInterfaces;
      networkConfig = {
        DHCP = "yes";
        IgnoreCarrierLoss = "3s";
      };
      dhcpV4Config = {
        RouteMetric = 300;
      };
      ipv6AcceptRAConfig = {
        RouteMetric = 300;
      };
    };
  };

  systemd.services.wpa_supplicant = {
    wants = ["agenix.service"];
    after = ["agenix.service"];

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
