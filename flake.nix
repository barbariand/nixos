{
  description = "SIMD.ME flake";

  inputs = {
    llm-agents.url = "github:numtide/llm-agents.nix";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sensible = {
      url = "github:urgobalt/sensible-nix/networkd_wifi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:NixOS/nixos-hardware";
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    sensible,
    nix-minecraft,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;
    user = "cindy";
    email = "cindy@simd.me";
    interface = "wlan0";
    full-name = "Cindy Nilsson";

    tunnels = import ./hosts/tunnels.nix {inherit lib interface;};
    syncthingModules = import ./hosts/syncthing.nix {inherit interface;};
    loggingModules = import ./hosts/logging.nix {inherit lib;};

    globalPackages = {pkgs}:
      with pkgs; [
        rustup
        bacon
        wireguard-tools
        syncthing
        evtest
        nh
        nixos-anywhere
        unstable.git
        unstable.jujutsu
        docker
        bitwarden-cli
        unzip
        docker-compose

        btop
        eza
        trashy
        bat
        fd
        ripgrep
        mlocate
        bluetui
        brightnessctl
        pamixer
        gcc
        gnumake
        xdg-utils
        wget
        tldr
        unstable.just
        gh
        speedtest-rs
        sqlite
        aspell
        aspellDicts.sv
        aspellDicts.en
        aspellDicts.en-computers
        aspellDicts.en-science
        bitwarden-cli
      ];
    clientPackages = {pkgs}:
      with pkgs; [
      krita
        wireshark
        unstable.signal-desktop
        monocraft
        bruno
        rpi-imager
        gimp
        proton-vpn
        hyprmon
        moonlight-qt
        libreoffice
        inkscape
        gajim
        karere
      ];

    k3sCluster = import ./lib/k3s.nix {
      inherit lib;
      controllerHostname = "raspberrypi";
      controllerIp = "10.55.0.1";
      tokenFileFn = config: config.age.secrets.k3s-token.path;
      clusterInterface = interface;

      nodes = {
        server_one = {ip = "10.55.0.4";};
      };
    };

    # Helper function to replace your old getNamedModules logic
    getNamed = hostName: modulesSets:
      lib.concatMap (
        modSet:
          if modSet ? ${hostName}
          then
            (
              if builtins.isList modSet.${hostName}
              then modSet.${hostName}
              else [modSet.${hostName}]
            )
          else []
      )
      modulesSets;

    clientBaseModules = [
      syncthingModules
      ./hosts/docker-client.nix
      ({pkgs, ...}: {environment.systemPackages = clientPackages {inherit pkgs;};})
    ];

    serverBaseModules = [];

    systemConfigs = sensible.nixosModules.default {
      default = {
        username = user;
        specialArgs = {
          inherit email interface full-name inputs self;
          outPath = self.outPath;
          wallpaper = ./background.jpg;
        };
        modules = [

          inputs.agenix.nixosModules.default
          ({
            user,
            pkgs,
            ...
          }: {
            home-manager.users.${user}.imports = [
              inputs.agenix.homeManagerModules.default
              ./secrets/home.nix
            ];
          })
          ({
            config,
            user,
            pkgs,
            ...
          }: {
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
              wallpaper.source = ./background.jpg;
            };
          })
          ./ssh.nix
          ./secrets/system.nix
          ./hosts/ccache.nix
          ./hosts/networking.nix
          ./hosts/common.nix
          ./hosts/user_groups.nix
          ./modules/atlas.nix
          ./modules/homepage.nix
          ({pkgs, ...}: {
            environment.systemPackages = globalPackages {inherit pkgs;};
          })
        ];
      };

      systems = {
        homecomputer = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            clientBaseModules
            ++ (getNamed "homecomputer" [tunnels loggingModules])
            ++ [
              ({pkgs, ...}: {environment.systemPackages = with pkgs; [opencode parsec-bin prismlauncher heroic krita opentabletdriver];})
              ({
                config,
                pkgs,
                inputs,
                ...
              }: {
                nixpkgs.overlays = [inputs.llm-agents.overlays.shared-nixpkgs];
                environment.systemPackages = with pkgs; [llm-agents.pi];
                home-manager.users.${user}.home.sessionPath = [
                  "${config.home-manager.users.${user}.home.homeDirectory}/.npm-packages"
                ];
              })
              ({pkgs, ...}: {
                services.flatpak.enable = true;
                nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) ["modrinth-app" "openclaw"];
                nixpkgs.config.permittedInsecurePackages = ["openclaw-2026.5.7"];
                security.polkit.enable = true;
              })
              ./hosts/llm.nix
              ./hosts/homecomputer/disk-config.nix
              ./hosts/homecomputer/hardware-configuration.nix
              ./hosts/homecomputer/system.nix
            ];
        };

        "lenovo-yoga" = {
          system = "x86_64-linux";
          stateVersion = "26.05";

          disko = true;
          modules =
            clientBaseModules
            ++ (getNamed "lenovo-yoga" [tunnels loggingModules])
            ++ [
              ({pkgs, ...}: {
services.flatpak.enable = true;
              environment.systemPackages = with pkgs; [heroic sage];})
              (
                import
                ./hosts/wifi.nix
                {}
              )
              ./hosts/lenovo-yoga/disk-config.nix
              ./hosts/lenovo-yoga/hardware-configuration.nix
              ./hosts/lenovo-yoga/system.nix
            ];
        };

        pi_sd = {
          system = "aarch64-linux";
          stateVersion = "26.05";
          disko = false;
          modules =
            serverBaseModules
            ++ (getNamed "raspberrypi" [tunnels loggingModules k3sCluster])
            ++ [
              {networking.hostName = lib.mkForce "raspberrypi";}
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

              (
                import
                ./hosts/wifi.nix
                {}
              )
              ./hosts/raspberrypi/disk-config.nix
              ./hosts/raspberrypi/hardware-configuration.nix
              ./hosts/raspberrypi/system.nix
              ./hosts/raspberrypi/vaultwarden.nix
              ./hosts/raspberrypi/homepage.nix
              ./hosts/raspberrypi/networking.nix
              syncthingModules
            ];
        };

        raspberrypi = {
          system = "aarch64-linux";
          stateVersion = "26.05";
          disko = false;
          modules =
            serverBaseModules
            ++ (getNamed "raspberrypi" [tunnels loggingModules k3sCluster])
            ++ [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              (
                import
                ./hosts/wifi.nix
                {}
              )
              ./hosts/raspberrypi/disk-config.nix
              ./hosts/raspberrypi/hardware-configuration.nix
              ./hosts/raspberrypi/system.nix
              ./hosts/raspberrypi/vaultwarden.nix
              ./hosts/raspberrypi/homepage.nix
              ./hosts/raspberrypi/networking.nix
              syncthingModules
              inputs.hardware.nixosModules.raspberry-pi-4
            ];
        };

        server_one = {
          system = "x86_64-linux";
          stateVersion = "26.05";

          disko = true;
          modules =
            serverBaseModules
            ++ (getNamed "server_one" [tunnels loggingModules k3sCluster])
            ++ [
              ./modules/ark-server.nix
              ./hosts/server_one/ark-server.nix
              nix-minecraft.nixosModules.minecraft-servers
              ({...}: {nixpkgs.overlays = [nix-minecraft.overlay];})
              ./hosts/server_one/minecraft.nix
              ./hosts/server_one/disk-config.nix
              ./hosts/server_one/system.nix
              ./hosts/server_one/hardware-configuration.nix
            ];
        };
      };
    };
  in {
    nixosConfigurations = systemConfigs.nixosConfigurations;

    devShells = lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        name = "simd-shell";
        buildInputs = with pkgs; [
          pkgs-unstable.just
          jq
          wireguard-tools
          nh
        ];
        shellHook = ''
          alias d="just deploy"
          alias u="just update"
        '';
      };
    });
  };
}
