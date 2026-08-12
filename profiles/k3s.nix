{lib, interface}: let
    k3sCluster = import ./lib/k3s.nix {
      inherit lib;
      controllerHostname = "raspberrypi";
      controllerIp = "10.55.0.1";
      tokenFileFn = config: config.age.secrets.k3s-token.path;
      clusterInterface = interface;
      nodes = {
        server_one = { ip = "10.55.0.4"; };
      };
    };
    in 
    k3sCluster
