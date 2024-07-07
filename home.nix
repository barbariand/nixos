{ lib, pkgs, ... }:
let
  unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
in
{
  imports = [
    <home-manager/nixos>
  ];

  # User
  users.users.cindy = {
    uid = 1000;
    isNormalUser = true;
    home = "/home/cindy";
    description = "Cindy Nilsson";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };


# Home
  home-manager.users.cindy = { pkgs, config, ... }: {

    nixpkgs = {
      config = {
        allowInsecurePredicate = pkg: builtins.elem (lib.getName pkg) [
          "electron"
        ];
        allowUnfree=true;
      };
    };
    #enableing kitty
    programs.kitty={
      enable=true;
      theme="Blazer";
      extraConfig=''
        font_family FiraCode
  	font_size 14.0

      '';
    };
    home = {
      sessionVariables = {
        XDG_CONFIG_HOME = "$HOME/.config";
        SSH_HOME = "$HOME/.ssh";
        MANPAGER = "nvim +Man!";
        MANWIDTH = 999;
        PF_INFO = "ascii shell editor host uptime memory palette";
      };


      # Packages managed by home manager
      packages = with pkgs; [
        # System
        eza
        zsh
        trashy
        bat
        unixtools.xxd
        fastfetch
        inotify-tools

        # Rust build systems
        cargo-info
        rustup
        # Package managers
         opam
         unstable.pnpm

        # Programming languages
        nodejs_22
        go
        ocaml

        # Erlang
        unstable.gleam
        erlang
        rebar3
        elixir

        # Lsp
        lua-language-server
        nil
        elixir-ls
        tailwindcss-language-server

        # Linters
        eslint_d

        # Formatters
        stylua

        # Utils
        speedtest-rs
        ripgrep

        # Databases
        sqlite

        # Hacking the brain
        toipe
        # obsidian
        neomutt

        #Destroying the brain
        steam

        #Comunication
        discord
      ];

      # Version of the originally installed home-manager
      stateVersion = "24.05";
    };

    imports = [
      ./config/git.nix
      ./config/exports.nix
    ];
  };
}
