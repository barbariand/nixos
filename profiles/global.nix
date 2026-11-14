{
  config,
  pkgs,
  user,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.agenix.nixosModules.default
    ../modules/default.nix
    ../ssh.nix
    ../secrets/system.nix
    ./tunnels.nix
  ];
  sensible.ccache.enable = false;
  sensible.docker.enable = true;

  nix.settings = {
    substituters = [
      "https://cache.simd.me/simd"
    ];

    trusted-public-keys = [
      "simd:W4tMJwzanoMh2lKYEqQ+fClSwdVQumrFURjpXV8+Stc="
    ];

    netrc-file = config.age.secrets.nix-netrc.path;
  };
  users.users.${user}.extraGroups = [
    "docker"
    "wireshark"
    "minecraft"
  ];
  nix.settings.experimental-features = lib.mkForce [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  documentation = {
    enable = true;
    man.enable = true;
    man.cache.enable = false;
  };

  nixpkgs.overlays = [
    (final: prev: {
      makeSecurityWrapper = prev.makeSecurityWrapper.override {
        stdenv = prev.stdenv;
      };
      pkgsMusl = prev.pkgsMusl.overrideScope (mFinal: mPrev: {
        stdenv = prev.stdenv;
      });
    })
    (uFinal: uPrev: {
      python312 = uPrev.python312.override {
        packageOverrides = pyFinal: pyPrev: {
          whatthepatch = pyPrev.whatthepatch.overridePythonAttrs (_: {
            doCheck = false;
          });
          python-lsp-server = pyPrev.python-lsp-server.overridePythonAttrs (_: {
            doCheck = false;
          });
        };
      };
    })
  ];
  environment.systemPackages = with pkgs; [
    # Nix & System Management
    nh
    nixos-anywhere

    # Development: Core Toolchains & Build Tools
    gnumake
    unstable.just
    dig

    # Development: Version Control & Forge CLIs
    gh
    unstable.git
    unstable.jujutsu

    # Modern Core Utilities & Replacements
    bat
    btop
    eza
    fd
    ripgrep
    trashy

    # Classic System Utilities & Hardware Inspection
    evtest
    mlocate
    tldr
    unzip
    wget

    # Networking, Connectivity & Sync
    speedtest-rs
    syncthing
    wireguard-tools

    # Databases
    sqlite
  ];

  home-manager.users.${user}.imports = [
    inputs.agenix.homeManagerModules.default
    ../secrets/home.nix
  ];

  sensible = {
    secrets = {
      enable = true;
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
      features = [
        "rust"
        "html-css-js"
        "tailwindcss"
      ];
    };
    wallpaper.source = ../background.jpg;
  };
  sensible.networking = {
    nameservers = [];
    fallbackDns = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };
}
