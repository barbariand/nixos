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
    nixpkgs,
    sensible-nix,
    nvim,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;

    clusterData = {
      raspberrypi = {
        ip = "10.0.0.1";
        id = "@PI_ST_ID@";
      };
      homecomputer = {
        ip = "10.0.0.2";
        id = "@HOME_ST_ID@";
      };
      "lenovo-yoga" = {
        ip = "10.0.0.3";
        id = "@YOGA_ST_ID@";
      };
    };
    keys = import ./ssh {};

    #tunnels = import ./lib/wireguard.nix {
    # inherit lib;
    #   port = 51820;
    #   interface = "wlan0";
    #  endpoint = "simd.me";
    # privateKeyFile = "/etc/wireguard/private.key";
    # publicKey = keys.raspberrypi;
    # peers = {
    #   homecomputer = keys.home_computer;
    #   "lenovo-yoga" = keys.lenovo;
    # };
    # serverName = "raspberrypi";
    #};

    syncthingNodes = import ./lib/syncthing.nix {
      inherit lib;
      clusterMap = clusterData;
      user = "cindy";
      syncPath = "/etc/nixos";
    };
    mkSystem = sensible-nix.nixosModules.mkSystem {
      user = "cindy";
      email = "cindy@simd.me";
      full-name = "Cindy Nilsson";
      nvim-config = nvim;
      outPath = self.outPath;
      wallpaper = ./background.jpg;
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
        rpi-imager
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
          #tunnels.homecomputer

          #syncthingNodes."homecomputer"
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
          # tunnels."lenovo-yoga"

          # syncthingNodes."lenovo-yoga"
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
            virtualisation.docker.enable = true;
            users.extraGroups.docker.members = ["cindy"];
            virtualisation.docker.rootless = {
              enable = true;
              setSocketVariable = true;
            };
            environment.systemPackages = with pkgs;
              [
                heroic
                sage
              ]
              ++ common_packages {inherit pkgs;} ++ common_de_packages {inherit pkgs;};
          })
        ];
      };

      raspberrypi = mkSystem "raspberrypi" {
        system = "aarch64-linux";
        disko = false;
        extraModules = [
          ({
            pkgs,
            config,
            ...
          }: {
            nixpkgs.overlays = [
              (final: prev: {
                python312Packages = prev.python312Packages.override {
                  overrides = pyFinal: pyPrev: {
                    whatthepatch = pyPrev.whatthepatch.overridePythonAttrs (old: {
                      doCheck = false;
                    });
                    python-lsp-server = pyPrev.python-lsp-server.overridePythonAttrs (old: {
                      doCheck = false;
                    });
                  };
                };
              })
            ];
          })
          #syncthingNodes."raspberrypi"
          #tunnels.raspberrypi
          inputs.hardware.nixosModules.raspberry-pi-4
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ];
      };
    };
  };
}
