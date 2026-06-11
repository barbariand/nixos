{
  description = "SIMD.ME flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sensible-nix = {
      url = "github:urgobalt/sensible-nix/26.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:NixOS/nixos-hardware";
    nvim = {
      url = "github:barbariand/nvim";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    sensible-nix,
    nix-minecraft,
    nvim,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;
    user = "cindy";
    email = "cindy@simd.me";
    interface = "wlan0";
    full-name = "Cindy Nilsson";

    tunnels = import ./hosts/tunnels.nix {inherit lib interface;};
    syncthingModules = import ./hosts/syncthing.nix {inherit interface;};
    globalPackages = {pkgs}: with pkgs; [rustup bacon wireguard-tools syncthing evtest nh nixos-anywhere unstable.jujutsu docker bitwarden-cli unzip docker-compose];
    clientPackages = {pkgs}: with pkgs; [wireshark unstable.signal-desktop monocraft bruno rpi-imager gimp proton-vpn hyprmon moonlight-qt libreoffice inkscape gajim karere];
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

    mkCluster = import ./lib/mkCluster.nix {
      inherit lib;
      mkSystem = sensible-nix.nixosModules.mkSystem {
        inherit user email full-name;
        nvim-config = nvim;
        outPath = self.outPath;
        wallpaper = ./background.jpg;
      };

      globalPackages = globalPackages;
      clientPackages = clientPackages;

      globalExtraModules = [./hosts/ccache.nix ./hosts/networking.nix ./hosts/common.nix ./hosts/user_groups.nix];
      clientExtraModules = [syncthingModules ./hosts/docker-client.nix];
      namedGlobalExtraModules = [tunnels];
      namedServerExtraModules = [k3sCluster];
    };
  in {
    nixosConfigurations = mkCluster {
      homecomputer = {
        system = "x86_64-linux";
        extraPackages = pkgs: with pkgs; [opencode prismlauncher heroic krita opentabletdriver];
        extraModules = [
          ({pkgs, ...}: {
            services.flatpak.enable = true;

            # Ensure the predicate is broad enough or correctly matched
            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem (pkgs.lib.getName pkg) [
                "modrinth-app"
                "openclaw" # Use the package name, not the version-suffixed string here
              ];

            # Explicitly permit the insecure version globally at the module level
            nixpkgs.config.permittedInsecurePackages = [
              "openclaw-2026.5.7"
            ];

            security.polkit.enable = true;
          })

          ./hosts/llm.nix
        ];
      };

      "lenovo-yoga" = {
        system = "x86_64-linux";
        extraPackages = pkgs: with pkgs; [heroic sage];
      };
      pi_sd = {
        system = "aarch64-linux";
        server = true;
        disko = false;
        hostnameOverride = "raspberrypi"; # Gör att maskinen heter raspberrypi trots flakens namn
        extraModules = [
          ./hosts/raspberrypi/vaultwarden.nix
          ./lib/atlas.nix
          syncthingModules
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ];
      };
      raspberrypi = {
        system = "aarch64-linux";
        server = true;
        disko = false;
        extraModules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./hosts/raspberrypi/vaultwarden.nix
          ./hosts/raspberrypi/networking.nix
          syncthingModules
          inputs.hardware.nixosModules.raspberry-pi-4
        ];
      };

      server_one = {
        system = "x86_64-linux";
        server = true;
        extraModules = [
          ./lib/ark-server.nix
          ./hosts/server_one/ark-server.nix
          nix-minecraft.nixosModules.minecraft-servers
          ({...}: {
            nixpkgs.overlays = [nix-minecraft.overlay];
          })
          ./hosts/server_one/minecraft.nix
        ];
      };
    };

    devShells = lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        name = "simd-shell";
        buildInputs = with pkgs; [
          just
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
