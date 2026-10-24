{pkgs, lib,...}: {
  config.sensible = {
    wireguard."wg0".enable = true;
    shell = {
      fish.enable = true;
      default = "fish";
    };
    terminal.default = "kitty";
    pass.enable = true;
    services.harmonia = {
      enable = true;
      port = 5000;
    };

    nix.extraOptions.secret-key-files = [ "/etc/nix/cache-priv-key.pem" ];

  boot.tmp.useTmpfs = true;

    networking.firewall.allowedTCPPorts = [ 5000 ];
  };
}
