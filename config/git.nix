{...}: {
    programs.git = {
      enable = true;
      userName = "Cindy Nilsson";
      userEmail = "cindynilsson@duck.com";
      extraConfig = {
        core.editor = "nvim";
        safe.directory = [
          "/etc/nixos"
        ];
        push.autoSetupRemote = true;
      };
    };
}
