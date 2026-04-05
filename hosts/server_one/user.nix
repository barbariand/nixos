{pkgs, ...}: {
  config.modules = {
    nvim.enable = true;
    fish.enable = true;
    git.enable = true;
    pass.enable = true;
    tmux.enable = true;

    packages.enable = true;
  };
}
