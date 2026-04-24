{
  lib,
  peers,
  ipBase,
  serverName,
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
  peerNames = builtins.attrNames peers;

  peerScripts =
    lib.mapAttrsToList (
      name: _pubKey: let
        index = lib.lists.findFirstIndex (n: n == name) null peerNames;
        ip = "${ipPrefix}.${builtins.toString (index + 2)}";
      in
        pkgs.writeShellScriptBin "ssh-${name}" ''
          echo "Connecting to ${name} (${ip}) via WireGuard..."
          exec ${pkgs.openssh}/bin/ssh ${user}@${ip} "$@"
        ''
    )
    peers;
in {
  environment.systemPackages = [serverScript] ++ peerScripts;
}
