{
  sensibleLib,
  user,
  config,
  ...
}: let
  wgLib = sensibleLib.wireguard;
  bthKeyPath = config.age.secrets.bth-ssh-key.path;
in {
  sensible.ssh-tools = {
    enable = true;
    defaultUser = user;

    wireguard = {
      enable = true;
      interfaces = ["wg0"];
      ignorePeers = ["phone"];
    };

    hosts = {
      bth = {
        user = "dani24";
        strictHostKeyChecking = "accept-new";
      };
      multiprocessor_server = {
        user = "dani24";
        strictHostKeyChecking = "no";
      };
    };
  };
  sensible.ssh-forwards = {
    enable = true;
    relayHost = "raspberrypi";
    serviceUser = user;
    wireguardInterface = "wg0";
    relayListenAddresses = [
      "127.0.0.1"
      "192.168.1.3"
    ];
    defaultUser = "dani24";
    defaultIdentityFile = bthKeyPath;

    tunnels = {
      bth = {
        targetHost = "ssh.student.bth.se";
        strictHostKeyChecking = "accept-new";
      };

      multiprocessor_server = {
        targetHost = "jane.lab.bth.se";
        proxyJump = "bth";
        strictHostKeyChecking = "no";
      };
    };
  };
  sensible.wireguard = {
    "wg1" = wgLib.mkIsolated {
      privateKeyFile = "/var/lib/wireguard/ollama.key";
      dns = ["10.56.0.1"];
      domains = [
        "!wireguard.simd.me"
        "~simd.me"
      ];
      firewall = {
        allowedTCPPorts = [
          53
          443
          853
        ];
        allowedUDPPorts = [
          53
          853
        ];
      };

      topology = {
        prefixLength = 24;
        nodes = {
          raspberrypi = {
            publicKey = "UgSUhfl9ORc4b5e59U2NdhXhfyDz4IvnUAM9iHL8tnY=";
            ip = "10.56.0.1";
          };
          homecomputer = {
            publicKey = "KfaPnCEKuEQE5HDOlQKddaJ+KkBuuZNetAdUk3483Bc=";
            ip = "10.56.0.2";
          };
          "viktor-homecomputer" = {
            publicKey = "sBag8Z0ucJIpJS8uqtiXV1B5PU1KL8FPBYp18+BFIhQ=";
            ip = "10.56.0.36";
          };
        };

        hubs.raspberrypi = {
          endpoint = "wireguard.simd.me";
          port = 51821;
        };
      };
    };

    "wg0" = wgLib.mkMesh {
      privateKeyFile = "/var/lib/wireguard/private.key";
      dns = ["10.55.0.1"];
      domains = [
        "!wireguard.simd.me"
        "~simd.me"
      ];
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
          build_server = {
            publicKey = "OVhRPoOU02tFUb32tPXqyxZqnM3Z3kOo9CywVeB4jns=";
            ip = "10.55.0.5";
          };
          phone = {
            publicKey = "HtWcEPpV156RJ5b/NKC0z9U7Fu4nh4935s1Jj21tZ0U=";
            ip = "10.55.0.200";
          };
          bth = {
            publicKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            ip = "10.55.0.20";
          };
          multiprocessor_server = {
            publicKey = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
            ip = "10.55.0.21";
          };
        };

        hubs.raspberrypi = {
          endpoint = "wireguard.simd.me";
          port = 51820;
        };
      };
    };
  };
}
