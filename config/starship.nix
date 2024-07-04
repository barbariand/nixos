{ ... }: {
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        format = "$username$directory$character";
	right_format = "$nix_shell$time";

	username = {
	  disabled = false;
	  show_always = true;
	  format = "[$user]($style) ";
	};

	directory = {
	  disabled = false;
	  read_only = " ";
	  home_symbol=" ";
	};

        nix_shell = {
            disabled = false;
            format = "[$symbol$state $name]($style)";
        };

	time = {
	  disabled = true;
	  format = "[$time]($style)";
	};
      };
    };
}
