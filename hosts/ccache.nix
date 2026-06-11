{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.ccache.enable = true;

  programs.ccache.cacheDir = "/var/cache/ccache";

  nix.settings.extra-sandbox-paths = [config.programs.ccache.cacheDir];

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
