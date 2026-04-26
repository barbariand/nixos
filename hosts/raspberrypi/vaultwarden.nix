{ config, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://vault.simd.me";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    };
  };
}
