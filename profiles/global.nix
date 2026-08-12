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
    rustup bacon wireguard-tools syncthing evtest nh
    nixos-anywhere unstable.git unstable.jujutsu
    bitwarden-cli unzip btop eza trashy
    bat fd ripgrep mlocate bluetui brightnessctl pamixer
    gcc gnumake xdg-utils wget tldr unstable.just gh
    speedtest-rs sqlite aspell aspellDicts.sv aspellDicts.en
    aspellDicts.en-computers aspellDicts.en-science bitwarden-cli
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
    neovim = {
      enable = true;
      features = ["rust" "python" "html-css-js" "tailwindcss"];
    };
    wallpaper.source = ../background.jpg;
  };
}
