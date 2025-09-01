{
  description = "A example usecase of the flake.nix";
  inputs = {
    sensible-nix.url = "github:urgobalt/sensible-nix";
    sensible-nix.inputs.nixpkgs.follows = "nixpkgs";
    sensible-nix.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";

    hardware.url = "github:NixOS/nixos-hardware";

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nvim = {
      url = "github:urgobalt/nvim/main";
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
    common_packages = {pkgs}: with pkgs; [nh monocraft nixos-anywhere unstable.jujutsu docker];
    common_de_packages = {pkgs}:
      with pkgs; [
        whatsapp-for-linux
      ];
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
            nixpkgs.overlays = [
              (finalPkgs: previousPkgs: {
                heroic = previousPkgs.heroic.override {
                  # The extraPkgs function receives the *final* package set (finalPkgs)
                  # and should return a list of packages to include.
                  extraPkgs = drvPkgs: with drvPkgs; [gamescope];
                };
              })
            ];
            environment.systemPackages = with pkgs;
              [
                itch
                heroic
                krita
                modrinth-app
                opentabletdriver
                wacomtablet
              ]
              ++ common_packages {inherit pkgs;} ++ common_de_packages {inherit pkgs;};
            security.polkit.enable = true;
          })
        ];
      };
      lenovo-yoga = mkSystem "lenovo-yoga" {
        system = "x86_64-linux";
        disko = true;

        extraModules = [
          ({
            pkgs,
            config,
            ...
          }: {
            #virtualisation.virtualbox.host.enableExtensionPack = true;
            #users.extraGroups.vboxusers.members = ["cindy"];
            #virtualisation.virtualbox.host.enable = true;
            environment.systemPackages = with pkgs;
              [
                sage
              ]
              ++ common_packages {inherit pkgs;} ++ common_de_packages {inherit pkgs;};
          })
        ];
      };
    };
  };
}
