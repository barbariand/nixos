{lib, ...}: let
  wireguard = import ./wireguard {inherit lib;};
  atlas = import ./atlas {inherit lib;};
  sshTools = import ./ssh-tools {inherit lib;};
  sshForwards = import ./ssh-forwards {inherit lib;};
in {
  inherit
    wireguard
    atlas
    sshTools
    sshForwards
    ;
}
