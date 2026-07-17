let
  ssh = import ../ssh-keys.nix;
  default = ssh.users ++ ssh.systems;
in
  with ssh; {
    "user-password.age".publicKeys = default;
    "wifi-env.age".publicKeys = default;
    "nix-access-tokens.age".publicKeys = default;
    "k3s-token.age".publicKeys = default;
    "grafana.age".publicKeys = default;
    "homepage.env.age".publicKeys = default;

    # Email
    # "personal-email.age".publicKeys = ssh.users;
    # "professional-email.age".publicKeys = ssh.users;
  }
