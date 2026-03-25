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
    wgConfig = {pkgs}:
      (import ./lib/wireguard-network.nix {
        lib = sensible-nix.nixpkgs.lib;
        inherit pkgs;
      }) {
        serverName = "raspberrypi";
        clientNames = ["homecomputer" "lenovo-yoga"];
        externalDomain = "simd.me";
      };
    common_packages = {pkgs}:
      with pkgs; [
        hyprmon
        moonlight-qt
        libreoffice
        inkscape
        evtest
        unstable.signal-desktop
        nh
        monocraft
        nixos-anywhere
        unstable.jujutsu
        docker
        gimp
        bitwarden-cli
        protonvpn-gui
        unzip
        bruno
        docker-compose
      ];
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
                wgConfig.homecomputer
                heroic
                krita
                modrinth-app
                opentabletdriver
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
            virtualisation.docker.enable = true;
            users.extraGroups.docker.members = ["cindy"];
            virtualisation.docker.rootless = {
              enable = true;
              setSocketVariable = true;
            };
            environment.systemPackages = with pkgs;
              [
                wgConfig
                {inherit pkgs;}.lenovo-yoga
                sage
              ]
              ++ common_packages {inherit pkgs;} ++ common_de_packages {inherit pkgs;};
          })
        ];
      };
    };
    raspberrypi = mkSystem "raspberrypi" {
      system = "aarch64-linux";
      disko = false;
      extraModules = [
        (
          {pkgs, ...}: {
            environment.systemPackages = [
              wgConfig
              {inherit pkgs;}.raspberrypi
              ./hosts/raspberrypi/system.nix
              ./hosts/raspberrypi/user.nix
            ];
          }
        )
      ];
    };
  };
}
