{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.sensible.ccache;
in {
  options.sensible.ccache = {
    enable = mkEnableOption "Sensible ccache integration";
    
    cacheDir = mkOption {
      type = types.path;
      default = "/var/cache/ccache";
    };
    
    maxSize = mkOption {
      type = types.str;
      default = "20G";
    };
  };

  config = mkIf cfg.enable {
    programs.ccache.enable = true;
    programs.ccache.cacheDir = cfg.cacheDir;

    nix.settings.extra-sandbox-paths = [cfg.cacheDir];

    nixpkgs.overlays = [
      (final: prev: {
        ccacheWrapper = prev.ccacheWrapper.override {
          extraConfig = ''
            export CCACHE_DIR="${cfg.cacheDir}"
            export CCACHE_MAXSIZE="${cfg.maxSize}"
          '';
        };
      })
    ];
  };
}
