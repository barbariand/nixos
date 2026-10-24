{
  lib,
  sensible_option,
  ...
}:
with lib;
sensible_option {
  ccache = mkOption {
    default = {};
    type = types.submodule {
      options = {
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
    };
  };
}
