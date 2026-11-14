{
  config,
  lib,
  ...
}: let
  isServer = config.networking.hostName == "raspberrypi";
in {
  sensible.loki = {
    enable = true;
    serverNode = "raspberrypi";
    domain = "logs.simd.me";
    clients = [
      "homecomputer"
      "server_one"
      "build_server"
      "lenovo-yoga"
    ];
    secretKeyFile = lib.mkIf isServer config.age.secrets."grafana".path;
  };
}
