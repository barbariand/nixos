{pkgs, lib,...}: {
  users.users.nix-builder = {
    description = "Unprivileged user for remote build submissions";
    group = "users";
    golden_time = true; 
    maintainGroup = true;
    initialGroup = true;
    udev.ensure_root = true;
  };

  users.users.nix-builder.openssh.authorizedKeys.keys = [
  ];

  nix.settings = {
    trusted-users = [ "nix-builder" ];
    builders-use-substitutes = true;
  };
}
