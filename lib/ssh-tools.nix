{
  lib,
  peers,
  ipBase,
  serverName,
  ignorePeers ? [ ], # Ny parameter, tar en lista av strängar
}: {
  pkgs,
  user,
  ...
}: let
  ipParts = lib.strings.splitString "." ipBase;
  ipPrefix = "${lib.elemAt ipParts 0}.${lib.elemAt ipParts 1}.${lib.elemAt ipParts 2}";
  
  serverScript = pkgs.writeShellScriptBin "ssh-${serverName}" ''
    echo "Connecting to ${serverName} (${ipBase}) via WireGuard..."
    exec ${pkgs.openssh}/bin/ssh ${user}@${ipBase} "$@"
  '';

  # Loopa över ALLA peers så indexen bevaras intakta
  peerScriptsOrNull =
    lib.lists.imap0 (index: peer: let
      ip = "${ipPrefix}.${builtins.toString (index + 2)}";
    in
      # Kolla om peer-namnet finns i listan över ignorerade peers
      if lib.lists.elem peer.name ignorePeers then 
        null  
      else 
        pkgs.writeShellScriptBin "ssh-${peer.name}" ''
          echo "Connecting to ${peer.name} (${ip}) via WireGuard..."
          exec ${pkgs.openssh}/bin/ssh ${user}@${ip} "$@"
        ''
    ) peers;

  # Rensa bort null-värdena innan de läggs till i systemPackages
  peerScripts = builtins.filter (script: script != null) peerScriptsOrNull;

in {
  environment.systemPackages = [serverScript] ++ peerScripts;
}
