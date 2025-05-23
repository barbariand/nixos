{
  description = "A example usecase of the flake.nix";
  inputs = {
    sensible-nix.url = "github:aabrupt/sensible-nix";
    sensible-nix.inputs.nixpkgs.follows = "nixpkgs";
    sensible-nix.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";

    hardware.url = "github:NixOS/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nvim = {
      url = "github:barbariand/nvim/main";
      flake = false;
    };
  };
  outputs = {
    self,
    sensible-nix,
    nvim,
    ...
  }: let
    mkSystem = sensible-nix.nixosModules.mkSystem {
      user = "cindy";
      email = "dante@nilsson.name";
      full-name = "Cindy Nilsson";
      nvim-config = nvim;
      outPath = self.outPath;
      wallpaper = ./background.jpg;
    };
  in {
    nixosConfigurations = {
      homecomputer = mkSystem "homecomputer" {
        system = "x86_64-linux";
        disko = true;

        extraModules = [
          ({
            pkgs,
            config,
            ...
          }: {
            environment.systemPackages = with pkgs; [
              docker
              krita
              modrinth-app
              whatsapp-for-linux
              protontricks
              unstable.jujutsu
            ];
          })
        ];
      };
      lenovo-yoga = mkSystem "lenovo-yoga" {
        system = "x86_64-linux";
        disko = false;

        extraModules = [
          ({
            pkgs,
            config,
            ...
          }: {
            virtualisation.vmware.host.enable = true;
            environment.systemPackages = with pkgs; [
              whatsapp-for-linux
              sage
              protontricks
              unstable.jujutsu
            ];
          })
        ];
      };
    };
  };
}
