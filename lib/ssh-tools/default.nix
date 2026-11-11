{lib}: let
  wgLib = import ../wireguard {inherit lib;};
in rec {
  resolveWireguardNetworks = hostName: allWgNetworks: wgCfg: let
    activeNets = lib.filterAttrs (_: netCfg: wgLib.isNetworkActive hostName netCfg) allWgNetworks;
    filteredNets =
      if wgCfg.interfaces == []
      then activeNets
      else lib.filterAttrs (netName: _: lib.elem netName wgCfg.interfaces) activeNets;
    sortedNames = lib.sort (
      a: b: (wgLib.trustInterface filteredNets.${a}) && !(wgLib.trustInterface filteredNets.${b})
    ) (builtins.attrNames filteredNets);
  in {
    networks = filteredNets;
    inherit sortedNames;
  };

  deriveWireguardNodes = hostName: allWgNetworks: wgCfg: let
    resolved = resolveWireguardNetworks hostName allWgNetworks wgCfg;
    inherit (resolved) networks sortedNames;

    isAllowedPeer = name:
      name != hostName && !(lib.elem name wgCfg.ignorePeers);

    primaryNodes =
      lib.foldl' (
        acc: netName: let
          netCfg = networks.${netName};
          candidates = lib.filterAttrs (name: _: isAllowedPeer name && !(builtins.hasAttr name acc)) netCfg.topology.nodes;
        in
          acc
          // (lib.mapAttrs (_: nodeCfg: {
              inherit netName;
              hostname = nodeCfg.ip;
            })
            candidates)
      ) {}
      sortedNames;

    perNetNodes =
      lib.foldl' (
        acc: netName: let
          netCfg = networks.${netName};
          candidates = lib.filterAttrs (name: _: isAllowedPeer name) netCfg.topology.nodes;
          mapped =
            lib.mapAttrs' (
              nodeName: nodeCfg:
                lib.nameValuePair "${netName}-${nodeName}" {
                  inherit netName;
                  hostname = nodeCfg.ip;
                }
            )
            candidates;
        in
          acc // mapped
      ) {}
      sortedNames;
  in
    if !wgCfg.enable
    then {}
    else if wgCfg.perNetworkAliases
    then primaryNodes // perNetNodes
    else primaryNodes;

  resolveAllHosts = hostName: allWgNetworks: cfg: let
    wgNodes = deriveWireguardNodes hostName allWgNetworks cfg.wireguard;

    baseFromWg =
      lib.mapAttrs (
        _: info: {
          hostname = info.hostname;
          user = cfg.defaultUser;
          port = null;
          identityFile = null;
          proxyJump = null;
          forwardAgent = false;
          strictHostKeyChecking = null;
          extraOptions = {};
        }
      )
      wgNodes;

    explicitHosts =
      lib.mapAttrs (
        name: hCfg: let
          wgFallback = baseFromWg.${name} or null;
          resolvedHostname =
            if hCfg.hostname != null
            then hCfg.hostname
            else if wgFallback != null
            then wgFallback.hostname
            else name;
        in {
          hostname = resolvedHostname;
          user =
            if hCfg.user != null
            then hCfg.user
            else cfg.defaultUser;
          port = hCfg.port;
          identityFile = hCfg.identityFile;
          proxyJump = hCfg.proxyJump;
          forwardAgent = hCfg.forwardAgent;
          strictHostKeyChecking = hCfg.strictHostKeyChecking;
          extraOptions = hCfg.extraOptions;
        }
      )
      cfg.hosts;
  in
    baseFromWg // explicitHosts;

  mkSettings = resolvedHosts:
    lib.mapAttrs (
      _: h:
        {
          HostName = h.hostname;
          ForwardAgent = h.forwardAgent;
        }
        // lib.optionalAttrs (h.user != null) {User = h.user;}
        // lib.optionalAttrs (h.port != null) {Port = h.port;}
        // lib.optionalAttrs (h.identityFile != null) {IdentityFile = h.identityFile;}
        // lib.optionalAttrs (h.proxyJump != null) {ProxyJump = h.proxyJump;}
        // lib.optionalAttrs (h.strictHostKeyChecking != null) {
          StrictHostKeyChecking = h.strictHostKeyChecking;
        }
        // h.extraOptions
    )
    resolvedHosts;
}
