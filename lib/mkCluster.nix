{
  lib,
  mkSystem,
  globalPackages ? null,
  clientPackages ? null,
  serverPackages ? null,
  globalExtraModules ? [],
  serverExtraModules ? [],
  clientExtraModules ? [],
  namedGlobalExtraModules ? [],
  namedServerExtraModules ? [],
  namedClientExtraModules ? [],
}: hosts: let
  getNamedModules = listName: moduleList: hostName:
    lib.concatLists (lib.imap1 (
        index: moduleSet:
          if moduleSet ? ${hostName}
          then let
            value = moduleSet.${hostName};
          in
            if builtins.isList value
            then value
            else [value]
          else
            lib.warn "Warning in ${listName} at index ${toString index}: No configuration found for host '${hostName}'."
            []
      )
      moduleList);

  mapHost = name: cfg: let
    isServer = cfg.server or false;
    actualHostName = cfg.hostnameOverride or name;

    hostModules =
      globalExtraModules
      ++ (getNamedModules "namedGlobalExtraModules" namedGlobalExtraModules name)
      ++ (
        if isServer
        then serverExtraModules ++ (getNamedModules "namedServerExtraModules" namedServerExtraModules name)
        else clientExtraModules ++ (getNamedModules "namedClientExtraModules" namedClientExtraModules name)
      )
      ++ (cfg.extraModules or []);

    packageModule = {pkgs, ...}: {
      environment.systemPackages =
        (if globalPackages != null then globalPackages {inherit pkgs;} else [])
        ++ (
          if (!isServer)
          then (if clientPackages != null then clientPackages {inherit pkgs;} else [])
          else (if serverPackages != null then serverPackages {inherit pkgs;} else [])
        )
        ++ (if cfg ? extraPackages && cfg.extraPackages != null then cfg.extraPackages pkgs else []);
    };
  in
    mkSystem actualHostName {
      inherit (cfg) system;
      disko = cfg.disko or true;
      extraModules = hostModules ++ [packageModule];
    };
in
  lib.mapAttrs mapHost hosts
