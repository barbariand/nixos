{config, pkgs, ...}:

enviroment.systemPackages = with pkgs;[
 vim
 wget
 rustup
 git
 starship
 tmux
 gh
 firefox
];

home-manager.users.cindy={
 home.stateVersion="24.05";
 #enableing kitty
 programs.kitty={
  enable=true;
  theme="Blazers"
  extraConfig=''
  font_family FiraCode
  font_size 14.0

  '';
 };
};

programs.neovim = {
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
