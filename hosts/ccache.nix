{ config, pkgs, lib, ... }: {
  # Aktivera den globala ccache-modulen i NixOS
  programs.ccache.enable = true;

  # Ange var den persistenta cachen ska lagras på disken
  programs.ccache.cacheDir = "/var/cache/ccache";

  # Skruva upp maxstorleken på cachen (standard är ganska låg)
  nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];

  # Injektera ccache via en global nixpkgs-overlay
  nixpkgs.overlays = [
    (final: prev: {
      ccacheWrapper = prev.ccacheWrapper.override {
        extraConfig = ''
          export CCACHE_DIR="${config.programs.ccache.cacheDir}"
          export CCACHE_MAXSIZE="20G"
        '';
      };
    })
  ];
}
