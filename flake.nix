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
      url = "git+https://git.urgobalt.dev/urgobalt/sensible-nix.git";
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
      inputs.nixpkgs.follows = "nixpkgs";
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

    helpers = import ./lib/helpers.nix { inherit lib; };
    
    # Profile maps that return host-specific attributes
    loggingModules = import ./profiles/logging.nix { inherit lib; };
    
    k3sCluster = import ./profiles/k3s.nix { inherit lib interface; };
    
    clientBaseModules = [
      ./profiles/client.nix
    ];

    serverBaseModules = [];

    systemConfigs = sensible.nixosModules.default {
      default = {
        username = user;
        specialArgs = {
          inherit email interface full-name inputs self user;
          outPath = self.outPath;
          wallpaper = ./background.jpg;
        };
        modules = [
          ./profiles/global.nix
        ];
      };

      systems = {
        homecomputer = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            clientBaseModules
            ++ (helpers.getNamed "homecomputer" [ loggingModules ])
            ++ [
              ./hosts/homecomputer/default.nix
            ];
        };

        "lenovo-yoga" = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            clientBaseModules
            ++ (helpers.getNamed "lenovo-yoga" [ loggingModules ])
            ++ [
              ./profiles/wifi.nix
              ./hosts/lenovo-yoga/default.nix
            ];
        };

        pi_sd = {
          system = "aarch64-linux";
          stateVersion = "26.05";
          modules =
            serverBaseModules
            ++ (helpers.getNamed "raspberrypi" [ loggingModules ])
            ++ [
              { networking.hostName = lib.mkForce "raspberrypi"; }
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              ./profiles/wifi.nix
              ./hosts/raspberrypi/default.nix
            ];
        };

        raspberrypi = {
          system = "aarch64-linux";
          stateVersion = "26.05";
          modules =
            serverBaseModules
            ++ (helpers.getNamed "raspberrypi" [ loggingModules ])
            ++ [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              inputs.hardware.nixosModules.raspberry-pi-4
              ./profiles/wifi.nix
              ./hosts/raspberrypi/default.nix
            ];
        };

        server_one = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            serverBaseModules
            ++ (helpers.getNamed "server_one" [loggingModules ])
            ++ [
              ({ ... }: { nixpkgs.overlays = [ nix-minecraft.overlay ]; })
              nix-minecraft.nixosModules.minecraft-servers
              ./hosts/server_one/default.nix
            ];
        };
      };
    };
  in {
    nixosConfigurations = systemConfigs.nixosConfigurations;

    devShells = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: let
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
