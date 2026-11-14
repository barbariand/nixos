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
      url = "git+ssh://git@git.urgobalt.dev/urgobalt/sensible-nix.git";
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
      url = "github:ryantm/agenix/test/issue376-native-init";
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

    helpers = import ./lib/helpers.nix {inherit lib;};
    localLib = import ./lib/default.nix {inherit lib;};

    clientBaseModules = [
      ./profiles/client.nix
    ];

    serverBaseModules = [];

    systemConfigs = sensible.nixosModules.default {
      default = {
        username = user;
        specialArgs = {
          inherit
            email
            interface
            full-name
            inputs
            self
            user
            ;
          outPath = self.outPath;
          wallpaper = ./background.jpg;
          sensibleLib = {
            inherit
              (localLib)
              helpers
              wireguard
              atlas
              sshTools
              sshForwards
              ;
          };
        };
        modules = [
          ./profiles/global.nix
          ./profiles/loki.nix
        ];
      };

      systems = {
        homecomputer = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            clientBaseModules
            ++ [
              ({pkgs, ...}: {
                environment.systemPackages = with pkgs; [
                  prismlauncher
                  davinci-resolve
                  blender
                  #cisco-packet-tracer_9
                ];
              })
              ./hosts/homecomputer/default.nix
              ./profiles/llm.nix
              ./profiles/syncthing.nix
            ];
        };

        "lenovo-yoga" = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            clientBaseModules
            ++ [
              ({pkgs, ...}: {
                environment.systemPackages = with pkgs; [
                  dnsutils
                  davinci-resolve
                  blender
                  ffmpeg-full
                ];
              })
              ./profiles/wifi.nix
              ./profiles/syncthing.nix
              ./hosts/lenovo-yoga/default.nix
            ];
        };

        pi_sd = {
          system = "aarch64-linux";
          stateVersion = "26.05";
          modules =
            serverBaseModules
            ++ [
              {networking.hostName = lib.mkForce "raspberrypi";}
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              ./hosts/raspberrypi/default.nix
            ];
        };

        raspberrypi = {
          system = "aarch64-linux";
          stateVersion = "26.05";
          modules =
            serverBaseModules
            ++ [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              inputs.hardware.nixosModules.raspberry-pi-4
              ./profiles/syncthing.nix
              ./hosts/raspberrypi/default.nix
            ];
        };

        build_server = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            serverBaseModules
            ++ [
              ./hosts/build_server/default.nix
            ];
        };

        server_one = {
          system = "x86_64-linux";
          stateVersion = "26.05";
          disko = true;
          modules =
            serverBaseModules
            ++ [
              ({...}: {nixpkgs.overlays = [nix-minecraft.overlay];})
              nix-minecraft.nixosModules.minecraft-servers
              ./hosts/server_one/default.nix
            ];
        };
      };
    };
  in {
    nixosConfigurations = systemConfigs.nixosConfigurations;

    devShells = lib.genAttrs ["x86_64-linux" "aarch64-linux"] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

        gitSshFailover = pkgs.writeShellScript "git-ssh-failover" ''
          case "$*" in
            *git.urgobalt.dev*) ;;
            *) exec ${pkgs.openssh}/bin/ssh "$@" ;;
          esac

          stamp="/tmp/urgobalt-down.stamp"
          ttl=300
          is_down=0

          if [ -f "$stamp" ] && [ "$(( $(${pkgs.coreutils}/bin/date +%s) - $(${pkgs.coreutils}/bin/stat -c %Y "$stamp") ))" -lt "$ttl" ]; then
            is_down=1
          elif ! ${pkgs.coreutils}/bin/timeout 0.5 ${pkgs.netcat-openbsd}/bin/nc -z git.urgobalt.dev 22 2>/dev/null; then
            ${pkgs.coreutils}/bin/touch "$stamp"
            is_down=1
          else
            ${pkgs.coreutils}/bin/rm -f "$stamp" 2>/dev/null
          fi

          if [ "$is_down" -eq 1 ]; then
            args=()
            for arg in "$@"; do
              arg="''${arg//urgobalt\/sensible-nix/barbariand\/sensible-nix}"
              arg="''${arg//git@git.urgobalt.dev/git@github.com}"
              arg="''${arg//git.urgobalt.dev/github.com}"
              args+=("$arg")
            done
            exec ${pkgs.openssh}/bin/ssh "''${args[@]}"
          fi

          exec ${pkgs.openssh}/bin/ssh "$@"
        '';
      in {
        default = pkgs.mkShell {
          name = "simd-shell";
          buildInputs = with pkgs; [
            pkgs-unstable.just
            jq
            wireguard-tools
            nh
            ssh-to-age
            agenix-cli
            alejandra
            python3
          ];
          env = {
            PYTHONPATH = ".";
          };
          shellHook = ''
            export GIT_SSH_COMMAND="${gitSshFailover}"
            alias d="just deploy"
            alias u="just update"
          '';
        };
      }
    );
  };
}
