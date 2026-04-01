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
    experimentalModule = {...}: {
      nix.settings.experimental-features = lib.mkForce ["nix-command" "flakes" "pipe-operators"];
    };
    lib = nixpkgs.lib;
    user = "cindy";
    email = "cindy@simd.me";
    full-name = "Cindy Nilsson";
    interface = "wlan0";

    mkSystem = sensible-nix.nixosModules.mkSystem {
      inherit user email full-name;
      nvim-config = nvim;
      outPath = self.outPath;
      wallpaper = ./background.jpg;
    };

    clusterMap = {
      raspberrypi = {
        id = "GFDQ3LP-LXUFOFQ-TT5P4EG-NTW23RF-SXR2GVS-XNFUFOE-IISNZ4R-I5ZARAW";
      };
      homecomputer = {
        id = "CSUGSY3-3UAQVQF-7ITSVFQ-KJZ7RAY-Q3PBWKX-OAHMTIC-NMPYM2M-N55QNAS";
      };
      "lenovo-yoga" = {
        id = "QN3QYRB-BZPFGRD-2AOT3AD-XLKJ22N-LM275P4-QCXRIBZ-7GEZ6UX-PZFBNAE";
      };
    };

    tunnels = import ./lib/wireguard.nix {
      inherit lib interface;
      port = 51820;
      endpoint = "simd.me";
      privateKeyFile = "/etc/wireguard/private.key";
      publicKey = "z52vjMTykETjl7/tEXlEEAsKVJni5ocinvx5f21e91U=";
      ipBase = "10.55.0.1";
      peers = {
        homecomputer = "akkbT+7oQtZJ/FfVw69c6lFqlMw7c1lxuRmsf8iV2Rs=";
        "lenovo-yoga" = "Sm9H/b+pr8OJkVxj57ntfucm3SMFWNMFE42hB0Ygn04=";
      };
      serverName = "raspberrypi";
    };

    syncthingModules = import ./lib/syncthing.nix {
      inherit clusterMap interface;
      syncedFolders = {
        "nixos-config" = {
          id = "x4k9z-q1p2m";
          path = "/etc/nixos";
        };
      };
    };
    common_packages = {pkgs}:
      with pkgs; [
        syncthing
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
          tunnels.homecomputer
          experimentalModule
          syncthingModules
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
          tunnels."lenovo-yoga"

          experimentalModule
          syncthingModules
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
          experimentalModule
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

            environment.systemPackages = with pkgs;
              [
              ]
              ++ common_packages {inherit pkgs;};
          })
          syncthingModules
          tunnels.raspberrypi
          inputs.hardware.nixosModules.raspberry-pi-4
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ];
      };
    };
  };
}
