{ config, ... }: {
  imports = [
    (import ../lib/ssh-tools.nix {
      ignorePeers = [ "phone" ];
      sshUser = "cindy";
    })
  ];

  sensible.wireguard = {
    "wg-ollama"= {
      privateKeyFile = "/var/lib/wireguard/private.key";
      topology = {
        prefixLength = 24;

        nodes = {
          raspberrypi = {
            publicKey = "z52vjMTykETjl7/tEXlEEAsKVJni5ocinvx5f21e91U=";
            ip = "10.56.0.1";
          };
          #viktor_client = {
          #  publicKey = "";
          #  ip = "10.56.0.2";
          #};
          #viktor_client = {
          #  publicKey = "";
          #  ip = "10.56.0.3";
          #};
          #viktor_client = {
          #  publicKey = "";
          #  ip = "10.56.0.4";
          #};
        };

        hubs = {
          raspberrypi = {
            endpoint = "wireguard.simd.me";
            port = 51821;
            links = [ "friend_client" ];
          };
        };
      };
    };

    "wg0" = {
      privateKeyFile = "/etc/wireguard/private.key";
      topology = {
        prefixLength = 24;
        nodes = {
          raspberrypi = {
            publicKey = "z52vjMTykETjl7/tEXlEEAsKVJni5ocinvx5f21e91U=";
            ip = "10.55.0.1";
          };
          homecomputer = {
            publicKey = "akkbT+7oQtZJ/FfVw69c6lFqlMw7c1lxuRmsf8iV2Rs=";
            ip = "10.55.0.2";
          };
          "lenovo-yoga" = {
            publicKey = "Sm9H/b+pr8OJkVxj57ntfucm3SMFWNMFE42hB0Ygn04=";
            ip = "10.55.0.3";
          };
          server_one = {
            publicKey = "CKzdaPbPUgetkV+oI1+OYcZH7PvyM2UWPEPx6i2F+yM=";
            ip = "10.55.0.4";
          };
          phone = {
            publicKey = "HtWcEPpV156RJ5b/NKC0z9U7Fu4nh4935s1Jj21tZ0U=";
            ip = "10.55.0.5";
          };
        };

        hubs = {
          raspberrypi = {
            endpoint = "wireguard.simd.me";
            port = 51820;
            links = [ "homecomputer" "lenovo-yoga" "server_one" "phone" ];
          };
        };
      };
    };
  };
}
