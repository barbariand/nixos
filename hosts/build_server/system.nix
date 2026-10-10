{pkgs, lib,...}: {
  config.sensible = {
    wireguard."wg0".enable = false;
    shell = {
      fish.enable = true;
      default = "fish";
    };
    terminal.default = "kitty";
    pass.enable = true;
    tmux.enable = true;
  };
}
