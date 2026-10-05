{ config, pkgs, user, lib, inputs, ... }:
{
  imports = [
    inputs.agenix.nixosModules.default
    ../modules/default.nix
    ../ssh.nix
    ../secrets/system.nix
    ./tunnels.nix
  ];

  sensible.ccache.enable = true;
  sensible.docker.enable = true;

  users.users.${user}.extraGroups = ["docker" "wireshark" "minecraft"];
  nix.settings.experimental-features = lib.mkForce ["nix-command" "flakes" "pipe-operators"];
  
  documentation = {
    enable = true;
    man.enable = true;
    man.cache.enable = false;
  };

  nixpkgs.overlays = [
    (uFinal: uPrev: {
      python312 = uPrev.python312.override {
        packageOverrides = pyFinal: pyPrev: {
          whatthepatch = pyPrev.whatthepatch.overridePythonAttrs (_: {doCheck = false;});
          python-lsp-server = pyPrev.python-lsp-server.overridePythonAttrs (_: {doCheck = false;});
        };
      };
    })
  ];

  environment.systemPackages = with pkgs; [
      # Nix & System Management
      nh
      nixos-anywhere

      # Development: Toolchains & Build Tools
      bacon
      gcc
      gnumake
      rustup
      unstable.just

      # Development: Version Control & Forge CLIs
      gh
      unstable.git
      unstable.jujutsu

      # Development: Python Tooling
      basedpyright
      ruff

      # Modern Core Utilities & Replacements
      bat
      btop
      eza
      fd
      ripgrep
      trashy

      # Classic System Utilities & Hardware Inspection
      brightnessctl
      evtest
      mlocate
      pamixer
      tldr
      unzip
      wget
      xdg-utils

      # Networking, Connectivity & Sync
      bluetui
      speedtest-rs
      syncthing
      wireguard-tools

      # Security & Password Management
      bitwarden-cli

      # Databases
      sqlite

      # Spell Checking & Dictionaries
      aspell
      aspellDicts.en
      aspellDicts.en-computers
      aspellDicts.en-science
      aspellDicts.sv
  ];

  home-manager.users.${user}.imports = [
    inputs.agenix.homeManagerModules.default
    ../secrets/home.nix
  ];

  sensible = {
    secrets = {
      enable = true;
      password = "root";
      passwordFile = config.age.secrets.user-password.path;
    };
    sysinfo.default = "fastfetch";
    starship.enable = true;
    direnv.enable = true;
    zoxide.enable = true;

    dunst.enable = false;
    terminal.default = "kitty";
    shell = {
      fish.enable = true;
      default = "fish";
    };
    tmux.enable = true;
    neovim = {
      enable = true;
      features = ["rust" "html-css-js" "tailwindcss"];
    };
    wallpaper.source = ../background.jpg;
  };
}
