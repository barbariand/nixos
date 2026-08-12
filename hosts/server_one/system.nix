{...}: {
  config.sensible = {

    wireguard."wg0".enable = true;
    shell = {
      fish.enable = true;
      default = "fish";
    };
    pass.enable = true;
    tmux.enable = true;
  };
}
