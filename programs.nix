{config, pkgs, ...}:{

programs={
 #vim.enable=true;
 #wget.enable=true;
 #rustup.enable=true;
 git.enable=true;
 starship.enable=true;
 tmux.enable=true;
 #gh.enable=true;
 firefox.enable=true;
};
programs.neovim={
enable=true;
defaultEditor=true;
};
programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    zsh-autoenv.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "npm"
        "history"
        "node"
        "rust"
        "deno"
      ];
    };
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
    };
  };
}
