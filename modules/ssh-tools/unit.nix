{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.ssh-tools;
  hostName = config.networking.hostName;
  sshToolsLib = import ../../lib/ssh-tools {inherit lib;};

  resolvedHosts = sshToolsLib.resolveAllHosts hostName config.sensible.wireguard cfg;
  sshSettings = sshToolsLib.mkSettings resolvedHosts;

  wrapperScripts =
    lib.mapAttrsToList (
      alias: _:
        pkgs.writeShellScriptBin "ssh-${alias}" ''
          exec ${pkgs.openssh}/bin/ssh ${lib.escapeShellArg alias} "$@"
        ''
    )
    resolvedHosts;
in
  {
    condition = cfg.enable;

    assertions = [
      {
        assertion = cfg.wireguard.enable -> (config ? sensible && config.sensible ? wireguard);
        message = "sensible.ssh-tools: 'wireguard.enable' requires 'sensible.wireguard' to be loaded.";
      }
    ];

    system = {
      environment.systemPackages = lib.mkIf cfg.generateWrapperScripts wrapperScripts;
    };

    home-manager = {
      programs.ssh = {
        enable = true;
        settings = sshSettings;
      };
    };
  }
  |> sensibleLib.sensibleConfig
