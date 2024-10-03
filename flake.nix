{
  description = "A example usecase of the flake.nix";
  inputs = {
    sensible-nix.url = "github:aabrupt/sensible-nix";
    hardware.url = "github:NixOS/nixos-hardware";
    nvim = {
      url = "github:barbariand/nvim";
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
      email = "dante@nilsson.name";
      full-name = "Cindy Nilsson";
      nvim-config = nvim;
      outPath = self.outPath;
    };
  in {
    nixosConfigurations = {
      lenovo-yoga = mkSystem "lenovo-yoga" {
        system = "x86_64-linux";
        disko = false;
        extraModules = [
          ({
            pkgs,
            config,
            ...
          }: {
            virtualisation.vmware.host.enable = true;
            environment.systemPackages = with pkgs; [
              krita
              inkscape
              obs-studio
              whatsapp-for-linux
              google-chrome
            ];

            environment.etc."current-system-packages".text = let
              packages = builtins.map (p: "${p.name}") config.environment.systemPackages;
              sortedUnique = builtins.sort builtins.lessThan (pkgs.lib.lists.unique packages);
              formatted = builtins.concatStringsSep "\n" sortedUnique;
            in
              formatted;
          })
        ];
      };
    };
  };
}
