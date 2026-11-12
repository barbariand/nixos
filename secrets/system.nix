{user, ...}: {
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/home/${user}/.ssh/id_ed25519"
  ];
  age.secrets.user-password.file = ./user-password.age;
  age.secrets.wifi-env.file = ./wifi-env.age;
  age.secrets.nix-access-tokens.file = ./nix-access-tokens.age;
  age.secrets.k3s-token.file = ./k3s-token.age;
  age.secrets.grafana.file = ./grafana.age;
  age.secrets.cloudflare-token.file = ./cloudflare-token.age;
  age.secrets.ollama.file = ./ollama.age;

  age.secrets.atticd-env.file = ./atticd-env.age;
  age.secrets.forgejo-runner-tokens.file = ./urgobalt-forgejo-runner.age;
  age.secrets.nix-netrc = {
    file = ./nix-netrc.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.ci-ssh-key = {
    file = ./ci-ssh-key.age;
    owner = "root";
    mode = "0400";
  };
  age.secrets.bth-ssh-key = {
    file = ./bth-ssh-key.age;
    owner = user;
    mode = "0400";
  };
  age.secrets."homepage.env" = {
    file = ./homepage.env.age;
  };
}
