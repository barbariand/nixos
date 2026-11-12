{
  config,
  lib,
  pkgs,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.ssh-forwards;
  wgCfg = config.sensible.wireguard or {};
  hostName = config.networking.hostName;
  fwdLib = import ../../lib/ssh-forwards {inherit lib;};

  resolvedTunnels = fwdLib.resolveTunnels wgCfg cfg;
  isRelay = fwdLib.isRelayHost hostName cfg;
  virtualAddresses = fwdLib.collectVirtualAddresses resolvedTunnels;

  relayOwnWgIp =
    if
      cfg.wireguardInterface
      != null
      && builtins.hasAttr cfg.wireguardInterface wgCfg
      && builtins.hasAttr hostName wgCfg.${cfg.wireguardInterface}.topology.nodes
    then [wgCfg.${cfg.wireguardInterface}.topology.nodes.${hostName}.ip]
    else [];

  sshdBindAddrs = unique (relayOwnWgIp ++ cfg.relayListenAddresses);

  mkTunnelService = name: tCfg: let
    jumpSpec = fwdLib.resolveProxyJump resolvedTunnels tCfg;
    fwdArgs = fwdLib.mkForwardArgs tCfg;
    destination =
      if tCfg.resolvedUser != null
      then "${tCfg.resolvedUser}@${tCfg.targetHost}"
      else tCfg.targetHost;

    sshCmd = concatStringsSep " \\\n  " (
      [
        "${pkgs.openssh}/bin/ssh -N"
        "-o ServerAliveInterval=${toString cfg.serverAliveInterval}"
        "-o ServerAliveCountMax=${toString cfg.serverAliveCountMax}"
        "-o ExitOnForwardFailure=yes"
      ]
      ++ optional (tCfg.resolvedStrictHostKey != null) "-o StrictHostKeyChecking=${tCfg.resolvedStrictHostKey}"
      ++ optional (tCfg.resolvedIdentity != null) "-i ${escapeShellArg tCfg.resolvedIdentity} -o IdentitiesOnly=yes"
      ++ optional (jumpSpec != null) "-J ${escapeShellArg jumpSpec}"
      ++ fwdArgs
      ++ tCfg.extraArgs
      ++ [destination]
    );
  in
    nameValuePair "ssh-forward-${name}" {
      description = "SSH Port Forward to ${destination} on ${tCfg.resolvedIp}";
      after = [
        "network-online.target"
        "systemd-networkd.service"
        "sshd.service"
        "agenix-install-secrets.service"
      ];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        User = cfg.serviceUser;
        AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
        CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
        Restart = "always";
        RestartSec = "10s";
        ExecStart = sshCmd;
      };
    };

  wrapperScripts =
    mapAttrsToList (
      alias: _:
        pkgs.writeShellScriptBin "ssh-${alias}" ''
          exec ${pkgs.openssh}/bin/ssh ${escapeShellArg alias} "$@"
        ''
    )
    resolvedTunnels;
in
  {
    condition = cfg.enable;

    assertions = fwdLib.mkAssertions wgCfg cfg resolvedTunnels;

    system = {
      boot.kernel.sysctl = mkIf (isRelay && cfg.manageRelaySshdListenAddresses) {
        "net.ipv4.ip_nonlocal_bind" = 1;
      };

      services.openssh.listenAddresses = mkIf (isRelay && cfg.manageRelaySshdListenAddresses) (
        map (addr: {
          inherit addr;
          port = 22;
        })
        sshdBindAddrs
      );

      systemd.network.networks = mkIf (isRelay && cfg.wireguardInterface != null && virtualAddresses != []) {
        "30-${cfg.wireguardInterface}".address = virtualAddresses;
      };

      systemd.services = mkIf isRelay (mapAttrs' mkTunnelService resolvedTunnels);

      environment.systemPackages = mkIf cfg.generateWrapperScripts wrapperScripts;
    };

    home-manager = {
      programs.ssh = {
        enable = true;
        settings = fwdLib.mkClientSettings resolvedTunnels;
      };
    };
  }
  |> sensibleLib.sensibleConfig
