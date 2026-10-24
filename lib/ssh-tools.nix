{
  ignorePeers ? [],
  sshUser ? "root",
}:
{ config, pkgs, lib, ... }:
let
  hostName = config.networking.hostName;
  wgLib = import ./wireguard { inherit lib; };

  activeNets = lib.filterAttrs (_: netCfg: wgLib.isNetworkActive hostName netCfg) config.sensible.wireguard;

  sortedNetNames = lib.sort (
    a: b:
      (wgLib.trustInterface activeNets.${a}) && !(wgLib.trustInterface activeNets.${b})
  ) (builtins.attrNames activeNets);

  primaryNodes = lib.foldl' (acc: netName: let
    netCfg = activeNets.${netName};
    candidates = lib.filterAttrs (
      name: _:
        name != hostName
        && !(lib.elem name ignorePeers)
        && !(builtins.hasAttr name acc)
    ) netCfg.topology.nodes;
  in
    acc // (lib.mapAttrs (_: nodeCfg: { inherit netName; ip = nodeCfg.ip; }) candidates)
  ) {} sortedNetNames;

  primaryScripts = lib.mapAttrsToList (nodeName: info:
    pkgs.writeShellScriptBin "ssh-${nodeName}" ''
      echo "Connecting to ${nodeName} (${info.ip}) via WireGuard (${info.netName})..."
      exec ${pkgs.openssh}/bin/ssh ${sshUser}@${info.ip} "$@"
    ''
  ) primaryNodes;

  perNetScripts = lib.flatten (lib.mapAttrsToList (netName: netCfg:
    lib.mapAttrsToList (nodeName: nodeCfg:
      pkgs.writeShellScriptBin "ssh-${netName}-${nodeName}" ''
        echo "Connecting to ${nodeName} (${nodeCfg.ip}) via WireGuard (${netName})..."
        exec ${pkgs.openssh}/bin/ssh ${sshUser}@${nodeCfg.ip} "$@"
      ''
    ) (lib.filterAttrs (name: _: name != hostName && !(lib.elem name ignorePeers)) netCfg.topology.nodes)
  ) activeNets);
in
{
  environment.systemPackages = primaryScripts ++ perNetScripts;
}
