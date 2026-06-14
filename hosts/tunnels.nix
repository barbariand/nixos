{
  lib,
  interface,
  ...
}: let
  ipBase = "10.55.0.1";

  peers = [
    {
      name = "homecomputer";
      publicKey = "akkbT+7oQtZJ/FfVw69c6lFqlMw7c1lxuRmsf8iV2Rs=";
    }
    {
      name = "lenovo-yoga";
      publicKey = "Sm9H/b+pr8OJkVxj57ntfucm3SMFWNMFE42hB0Ygn04=";
    }
    {
      name = "server_one";
      publicKey = "CKzdaPbPUgetkV+oI1+OYcZH7PvyM2UWPEPx6i2F+yM=";
    }
    {
      name = "phone";
      publicKey = "HtWcEPpV156RJ5b/NKC0z9U7Fu4nh4935s1Jj21tZ0U=";
    }
  ];

  publicKey = "z52vjMTykETjl7/tEXlEEAsKVJni5ocinvx5f21e91U=";
  serverName = "raspberrypi";

  wireguardTunnels = import ../lib/wireguard.nix {
    inherit lib interface ipBase peers publicKey serverName;
    port = 51820;
    endpoint = "simd.me";
    privateKeyFile = "/etc/wireguard/private.key";
  };

  sshModule = import ../lib/ssh-tools.nix {
    inherit lib ipBase serverName peers;
    ignorePeers = ["phone"];
  };
in
  lib.mapAttrs (name: wgConfig: [wgConfig sshModule]) wireguardTunnels
