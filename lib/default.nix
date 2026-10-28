{lib, ...}: let
  helpers = import ./helpers.nix {inherit lib;};
  wireguard = import ./wireguard {inherit lib;};
  atlas = import ./atlas {inherit lib;};
  sshTools = import ./ssh-tools.nix;
in {
  inherit
    helpers
    wireguard
    atlas
    sshTools
    ;
}
