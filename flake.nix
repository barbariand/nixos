{
  description = "A example usecase of the flake.nix";
  inputs = {
    sensible-nix.url = "github:urgobalt/sensible-nix";

    hardware.url = "github:NixOS/nixos-hardware";

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
      email = "cindy@simd.me";
      full-name = "Cindy Nilsson";
      nvim-config = nvim;
      outPath = self.outPath;
      wallpaper = ./background.jpg;
    };
    common_packages = {pkgs}: with pkgs; [hyprmon moonlight-qt libreoffice inkscape evtest unstable.signal-desktop nh monocraft nixos-anywhere unstable.jujutsu docker];
    common_de_packages = {pkgs}:
      with pkgs; [
        gajim
        wasistlos
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
                  extraPkgs = drvPkgs: with drvPkgs; [gamescope];
                };
              })
            ];
            fonts.packages = with pkgs; [
              corefonts

              comfortaa #
              (google-fonts.override {
                fonts = [
                  "Sniglet"
                  "Fredoka One"
                  "Balsamiq Sans"
                  "Chewy"
                ];
              })
            ];
            environment.systemPackages = with pkgs;
              [
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
