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
      # Force npm to install global packages here instead of the Nix store
      NPM_CONFIG_PREFIX = "${config.home-manager.users.${user}.home.homeDirectory}/.npm-global";
    };

    home.sessionPath = [
      # Ensure any binaries npm installs are executable from your shell
      "${config.home-manager.users.${user}.home.homeDirectory}/.npm-global/bin"
    ];
    programs.opencode.settings = {
      provider = {
        ollama = {
          # This points the client to the OpenAI-compatible endpoint
          baseURL = "http://localhost:11434/v1";
          # 'ollama' is a conventional placeholder for the API key
          apiKey = "ollama";
        };
      };
    };
  };
}
