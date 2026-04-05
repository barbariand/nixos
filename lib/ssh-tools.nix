{
  lib,
  peers,
  ipBase,
}: {
  pkgs,
  user,
  ...
}: let
  ipParts = lib.strings.splitString "." ipBase;
  ipPrefix = "${lib.elemAt ipParts 0}.${lib.elemAt ipParts 1}.${lib.elemAt ipParts 2}";

  sshScripts = lib.mapAttrsToList (
    name: _pubKey: let
      peerNames = builtins.attrNames peers;
      index = lib.lists.findFirstIndex (n: n == name) null peerNames;
      ip = "${ipPrefix}.${builtins.toString (index + 2)}";
    in
      pkgs.writeShellScriptBin "ssh-${name}" ''
        echo "Connecting to ${name} (${ip}) via WireGuard..."
        exec ${pkgs.openssh}/bin/ssh ${user}@${ip} "$@"
      ''
  ) (lib.filterAttrs (n: v: n != "phone") peers);
in {
  environment.systemPackages = sshScripts;
}
