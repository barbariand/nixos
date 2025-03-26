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
      home_computer = mkSystem "home_computer" {
        system = "x86_64-linux";
        disko = true;

        extraModules = [
          ({
            pkgs,
            config,
            ...
          }: {
            virtualisation.vmware.host.enable = true;
            environment.systemPackages = with pkgs; [
              krita
              modrinth-app
              inkscape
              whatsapp-for-linux
              sage
              protontricks
              lutris
              freecad-wayland
              jujutsu
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
              krita
              modrinth-app
              inkscape
              whatsapp-for-linux
              sage
              protontricks
              lutris
              freecad-wayland
              jujutsu
            ];
          })
        ];
      };
    };
  };
}
