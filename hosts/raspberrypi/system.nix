let
  networks = {
    "Cinderblock_5G" = {
      psk = "@PSK_CINDERBLOCK@";
      priority = 0;
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
