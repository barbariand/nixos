{pkgs, ...}: {
  config.modules = {
    # cli
    nvim.enable = true;
    fish.enable = true;
    git.enable = true;
    tmux.enable = true;
  };
}
