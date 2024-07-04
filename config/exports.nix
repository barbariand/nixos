{...}:{
 home.file={
 ".config/nvim/init.lua".source = ./nvim/init.lua;
 ".config/nvim/after".source=./nvim/after;
 ".config/nvim/lua".source=./nvim/lua;
 ".config/nvim/plugin".source=./nvim/plugin;};
 imports = [
  ./git.nix
  ./zsh.nix
  ./starship.nix
 ];
}
