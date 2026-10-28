{lib, ...}: let
  presetsLib = import ./presets.nix {inherit lib;};
  subdomainsLib = import ./subdomains.nix {inherit lib;};
  assertionsLib = import ./assertions.nix {inherit lib subdomainsLib;};
in
  presetsLib
  // subdomainsLib
  // assertionsLib
  // {
    presets = presetsLib;
    subdomains = subdomainsLib;
    assertions = assertionsLib;
  }
