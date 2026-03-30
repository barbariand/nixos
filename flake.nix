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
    user = "cindy";
    email = "cindy@simd.me";
    full-name = "Cindy Nilsson";

    mkSystem = sensible-nix.nixosModules.mkSystem {
      inherit user email full-name;
      nvim-config = nvim;
      outPath = self.outPath;
      wallpaper = ./background.jpg;
    };
    clusterData = {
      raspberrypi = {
        id = "@PI_ST_ID@";
      };
      homecomputer = {
        id = "@HOME_ST_ID@";
      };
      "lenovo-yoga" = {
        id = "@YOGA_ST_ID@";
      };
    };
    keys = import ./ssh {};

    tunnels = import ./lib/wireguard.nix {
      inherit lib;
      port = 51820;
      interface = "wlan0";
      endpoint = "simd.me";
      privateKeyFile = "/etc/wireguard/private.key";
      # publicKey = keys.raspberrypi;
      ipBase = "10.55.0.1";
      peers = {
        # homecomputer = keys.home_computer;
        # "lenovo-yoga" = keys.lenovo;
      };
      serverName = "raspberrypi";
    };

    syncthingNodes = import ./lib/syncthing.nix {
      inherit lib user;
      clusterMap = clusterData;
    };
    common_packages = {pkgs}:
      with pkgs; [
        evtest
        nh
        nixos-anywhere
        unstable.jujutsu
        docker
        bitwarden-cli
        unzip
        docker-compose
      ];
    common_de_packages = {pkgs}:
      with pkgs; [
        unstable.signal-desktop
        monocraft
        bruno
        rpi-imager
        gimp
        protonvpn-gui
        hyprmon
        moonlight-qt
        libreoffice
        inkscape
        gajim
        wasistlos
      ];
  in {
    nixosConfigurations = {
      homecomputer = mkSystem "homecomputer" {
        system = "x86_64-linux";
        disko = true;

        extraModules = [
          # tunnels.homecomputer

          ./lib/syncthing.nix
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
          #tunnels."lenovo-yoga"

          ./lib/syncthing.nix
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
            environment.systempackages = with pkgs;
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
                unstable = import inputs.nixpkgs-unstable {
                  system = prev.system;
                  config = prev.config; # Inherit allowUnfree and other settings
                  overlays = [
                    (uFinal: uPrev: {
                      python312Packages = uPrev.python312Packages.override {
                        overrides = pyFinal: pyPrev: {
                          python-lsp-server = pyPrev.python-lsp-server.overridePythonAttrs (old: {
                            doCheck = false;
                          });
                          whatthepatch = pyPrev.whatthepatch.overridePythonAttrs (old: {
                            doCheck = false;
                          });
                        };
                      };
                    })
                  ];
                };
              })
            ];

            environment.systempackages = with pkgs;
              [
              ]
              ++ common_packages {inherit pkgs;};
          })
          ./lib/syncthing.nix
          tunnels.raspberrypi
          inputs.hardware.nixosModules.raspberry-pi-4
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ];
      };
    };
  };
}
