{config, ...}: {
  imports = [./networking.nix];
  config.sensible = {
    shell = {
      fish.enable = true;
      default = "fish";
    };
    tmux.enable = true;
  };
}
