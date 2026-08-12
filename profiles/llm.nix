
{
  pkgs,
  user,
  config,
  ...
}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };
  nixpkgs.overlays = [
    (final: prev: {
      ollama-cuda = prev.ollama-cuda.override {
        stdenv = prev.ccacheStdenv;
      };
    })
  ];

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
