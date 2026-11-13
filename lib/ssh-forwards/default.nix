{lib}: let
  ipLib = import ../wireguard/ip.nix {inherit lib;};
in rec {
  isRelayHost = hostName: cfg:
    cfg.enable && (hostName == cfg.relayHost) && (cfg.tunnels != {});

  # Resolves bind IP: explicit bindIp -> matching node in sensible.wireguard.<interface>
  resolveTunnelIp = wgCfg: wgIf: name: tCfg:
    if tCfg.bindIp != null
    then tCfg.bindIp
    else if
      wgIf != null
      && builtins.hasAttr wgIf wgCfg
      && builtins.hasAttr name wgCfg.${wgIf}.topology.nodes
    then wgCfg.${wgIf}.topology.nodes.${name}.ip
    else null;

  resolveTunnels = wgCfg: cfg:
    lib.mapAttrs (
      name: tCfg: let
        resolvedIp = resolveTunnelIp wgCfg cfg.wireguardInterface name tCfg;
        resolvedIdentity =
          if tCfg.identityFile != null
          then tCfg.identityFile
          else cfg.defaultIdentityFile;
        resolvedUser =
          if tCfg.user != null
          then tCfg.user
          else cfg.defaultUser;
        resolvedStrictHostKey =
          if tCfg.strictHostKeyChecking != null
          then tCfg.strictHostKeyChecking
          else cfg.defaultStrictHostKeyChecking;
      in
        tCfg
        // {
          inherit name resolvedIp resolvedIdentity resolvedUser resolvedStrictHostKey;
        }
    )
    (lib.filterAttrs (_: t: t.enable) cfg.tunnels);

  # Returns the tunnel alias directly when referencing another tunnel so OpenSSH
  # picks up its Host block (IdentityFile, User, HostName, IdentitiesOnly) from ssh_config.
  resolveProxyJump = _resolvedTunnels: tCfg: tCfg.proxyJump;

  # Generates "-L bindIp:localPort:remoteHost:remotePort" arguments for a tunnel
  mkForwardArgs = tCfg:
    map (
      fwd: "-L ${tCfg.resolvedIp}:${toString fwd.localPort}:${fwd.remoteHost}:${toString fwd.remotePort}"
    )
    tCfg.forwards;

  # Deduplicated list of virtual IPs assigned to the relay's WireGuard interface
  collectVirtualAddresses = resolvedTunnels:
    lib.unique (
      map (t: "${t.resolvedIp}/32") (
        builtins.filter (t: t.resolvedIp != null) (lib.attrValues resolvedTunnels)
      )
    );

  # Generates Home Manager programs.ssh.settings blocks (ssh_config(5) directives)
  mkClientSettings = resolvedTunnels:
    lib.mapAttrs (
      _: tCfg:
        {
          HostName = tCfg.resolvedIp;
        }
        // lib.optionalAttrs (tCfg.resolvedUser != null) {
          User = tCfg.resolvedUser;
        }
        // lib.optionalAttrs (tCfg.resolvedIdentity != null) {
          IdentityFile = tCfg.resolvedIdentity;
          IdentitiesOnly = "yes";
        }
        // lib.optionalAttrs (tCfg.resolvedStrictHostKey != null) {
          StrictHostKeyChecking = tCfg.resolvedStrictHostKey;
        }
        // tCfg.clientExtraOptions
    )
    resolvedTunnels;

  mkAssertions = wgCfg: cfg: resolvedTunnels:
    [
      {
        assertion = cfg.enable -> (cfg.relayHost != "");
        message = "sensible.ssh-forwards: 'relayHost' must not be empty when enabled.";
      }
      {
        assertion =
          (cfg.enable && cfg.wireguardInterface != null)
          -> (builtins.hasAttr cfg.wireguardInterface wgCfg);
        message = "sensible.ssh-forwards: wireguardInterface '${toString cfg.wireguardInterface}' is not defined in config.sensible.wireguard.";
      }
    ]
    ++ (lib.mapAttrsToList (name: tCfg: {
      assertion = tCfg.resolvedIp != null && ipLib.isValidIPv4 tCfg.resolvedIp;
      message = "sensible.ssh-forwards: Tunnel '${name}' could not resolve a valid IPv4 'bindIp' (set bindIp explicitly or add '${name}' to sensible.wireguard.${toString cfg.wireguardInterface}.topology.nodes).";
    }) resolvedTunnels)
    ++ (lib.mapAttrsToList (name: tCfg: {
      assertion = tCfg.forwards != [];
      message = "sensible.ssh-forwards: Tunnel '${name}' must define at least one port forward in 'forwards'.";
    }) resolvedTunnels);
}
