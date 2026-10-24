{ lib, ... }:
let
  ipLib = import ./ip.nix { inherit lib; };
  topologyLib = import ./topology.nix { inherit lib ipLib; };
  nftablesLib = import ./nftables.nix { inherit lib topologyLib; };
  presetsLib = import ./presets.nix { inherit lib; };
  assertionsLib = import ./assertions.nix { inherit lib ipLib topologyLib; };
in
  ipLib
  // topologyLib
  // nftablesLib
  // presetsLib
  // assertionsLib
  // {
    ip = ipLib;
    topology = topologyLib;
    nftables = nftablesLib;
    presets = presetsLib;
    assertions = assertionsLib;
  }
