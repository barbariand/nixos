{
  description = "SIMD.ME flake";

  inputs = {
    sensible-nix.url = "github:urgobalt/sensible-nix/adding_configurable_overlays";
    nixpkgs-unstable.follows = "sensible-nix/nixpkgs-unstable";
    hardware.url = "github:NixOS/nixos-hardware";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nvim = {
      url = "github:urgobalt/nvim/main";
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
    interface = "wg0";
    full-name = "Cindy Nilsson";

    tunnels = import ./hosts/tunnels.nix {inherit lib interface;};
    syncthingModules = import ./hosts/syncthing.nix {inherit interface;};
    globalPackages = {pkgs}: with pkgs; [wireguard-tools syncthing evtest nh nixos-anywhere unstable.jujutsu docker bitwarden-cli unzip docker-compose];
    clientPackages = {pkgs}: with pkgs; [wireshark unstable.signal-desktop monocraft bruno rpi-imager gimp protonvpn-gui hyprmon moonlight-qt libreoffice inkscape gajim wasistlos];
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

      globalExtraModules = [./hosts/networking.nix ./hosts/common.nix ./hosts/user_groups.nix];
      clientExtraModules = [syncthingModules ./hosts/docker-client.nix];
      namedGlobalExtraModules = [tunnels];
      namedServerExtraModules = [k3sCluster];
    };
  in {
    nixosConfigurations = mkCluster {
      homecomputer = {
        system = "x86_64-linux";
        extraPackages = pkgs: with pkgs; [prismlauncher heroic krita modrinth-app opentabletdriver];
        extraModules = [
          ({pkgs, ...}: {
            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem (pkgs.lib.getName pkg) [
                "modrinth-app"
              ];
            nixpkgs.overlays = [
              (final: prev: {
                heroic = prev.heroic.override {
                  extraPkgs = p: [p.gamescope];
                };
              })
            ];
            security.polkit.enable = true;
          })
        ];
      };

      "lenovo-yoga" = {
        system = "x86_64-linux";
        extraPackages = pkgs: with pkgs; [heroic sage];
      };

      raspberrypi = {
        system = "aarch64-linux";
        server = true;
        disko = false;
        extraModules = [
          ./hosts/raspberrypi/vaultwarden.nix
          ./hosts/raspberrypi/networking.nix
          syncthingModules
          inputs.hardware.nixosModules.raspberry-pi-4
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
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
