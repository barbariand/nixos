{ 
  ignorePeers ? [ ], 
  sshUser ? "root" 
}: 
{ config, pkgs, lib, ... }:
let
  mkScriptsForNetwork = netName: netConfig:
    lib.mapAttrsToList (nodeName: nodeCfg:
      pkgs.writeShellScriptBin "ssh-${nodeName}" ''
        echo "Connecting to ${nodeName} (${nodeCfg.ip}) via WireGuard..."
        exec ${pkgs.openssh}/bin/ssh ${sshUser}@${nodeCfg.ip} "$@"
      ''
    ) (lib.filterAttrs (name: _: 
        name != config.networking.hostName && 
        !(lib.elem name ignorePeers)
      ) netConfig.topology.nodes);

  allScripts = lib.flatten (
    lib.mapAttrsToList (netName: netConfig:
      if netConfig.enable then
        mkScriptsForNetwork netName netConfig
      else
        []
    ) config.sensible.wireguard
  );
in 
{
  environment.systemPackages = allScripts;
}
