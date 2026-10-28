{config, ...}: {
  imports = [./networking.nix];
  config.sensible = {
    wireguard."wg0" = {
      enable = true;
      interface = "eth0";
    };
    wireguard."wg1" = {
      enable = true;
    };
    shell = {
      fish.enable = true;
      default = "fish";
    };
    terminal.default = "kitty";
    tmux.enable = true;
  };
}
