{
  config,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.ccache;
in
  {
    condition = cfg.enable;

    system = {
      programs.ccache = {
        enable = true;
        cacheDir = cfg.cacheDir;
      };

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
  |> sensibleLib.sensibleConfig
