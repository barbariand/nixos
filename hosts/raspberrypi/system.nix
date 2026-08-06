{config, ...}: {
  imports = [./networking.nix];
  config.sensible = {
    shell = {
      fish.enable = true;
      default = "fish";
    };
    terminal.default ="kitty";
    tmux.enable = true;
  };
}
