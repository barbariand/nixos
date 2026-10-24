{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.attic;

  pPostgres = import ./postgres.nix {inherit cfg pkgs;};
  pDaemon = import ./daemon.nix {inherit cfg lib;};
  pGc = import ./gc.nix {inherit cfg config pkgs;};
  pBootstrap = import ./bootstrap.nix {inherit cfg config lib pkgs;};
in
  {
    condition = cfg.enable;

    assertions = [
      {
        assertion = hasSuffix "/" cfg.apiEndpoint;
        message = "sensible.attic: 'apiEndpoint' must end with a trailing slash (e.g. 'https://cache.simd.me/').";
      }
    ];

    system = {
      users = pDaemon.users;
      systemd.tmpfiles.rules = pDaemon.systemd.tmpfiles.rules;

      services.postgresql = pPostgres.services.postgresql;
      services.atticd = pDaemon.services.atticd;

      systemd.services =
        pDaemon.systemd.services
        // pGc.systemd.services
        // pBootstrap.systemd.services;

      systemd.timers = pGc.systemd.timers;

      environment.systemPackages = [
        pkgs.attic-client
        config.services.atticd.package
      ];

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
    };
  }
  |> sensibleLib.sensibleConfig
