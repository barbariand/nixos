
{
  pkgs,
  user,
  config,
  ...
}: {
  nix.settings = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  home-manager.users.${user} = {
    home.sessionVariables = {
      NPM_CONFIG_PREFIX = "${config.home-manager.users.${user}.home.homeDirectory}/.npm-global";
    };

    home.sessionPath = [
      "${config.home-manager.users.${user}.home.homeDirectory}/.npm-global/bin"
    ];
    programs.opencode.settings = {
      provider = {
        ollama = {
          baseURL = "http://localhost:11434/v1";
          apiKey = "ollama";
        };
      };
    };
  };
}
