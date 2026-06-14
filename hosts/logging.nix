{lib}: let
  logging = import ../lib/logging.nix {
    inherit lib;
    domain = "logs.simd.me";
    clients = ["homecomputer" "server_one"];
    serverName = "raspberrypi";
    secretKeyFileFn = {config}: config.age.secrets."grafana".path;
  };
in
  logging
