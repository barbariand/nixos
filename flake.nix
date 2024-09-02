{
  description="A example usecase of the flake.nix";
  inputs={
	    sensible-nix.url="github:aabrupt/sensible-nix";
    hardware.url = "github:NixOS/nixos-hardware";
    nvim={
      url="github:aabrupt/nvim";
      flake=false;
    };
    };
  outputs={self,sensible-nix,nvim,...}:
  let mkSystem = sensible-nix.nixosModules.mkSystem {
    user="cindy"; 
    full-name="Cindy Nilsson";
    nvim-config=nvim;
    outPath=self.outPath;
    };
  in{
    nixosConfigurations={
      lenovo-yoga=mkSystem "lenovo-yoga" {
        system="x86_64-linux";
        disko=false;
        extraModules=[
        ({pkgs,...}: {
          environment.systemPackages = with pkgs; [
        krita
        vscode-fhs
        whatsapp-for-linux
        google-chrome
          ];
        })
        ];
      };
    };
  };
}
