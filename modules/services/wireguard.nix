{
  lib,
  wgCfg,
  wgIf,
}:
let
  # Check if the interface and node exist in the topology
  isValid = builtins.hasAttr wgIf wgCfg;
in
{
  # Function to resolve dynamic addresses for a given node
  resolveAddresses = nodeName:
    if isValid && builtins.hasAttr nodeName wgCfg.${wgIf}.topology.nodes then [
      "tcp://${wgCfg.${wgIf}.topology.nodes.${nodeName}.ip}:22000"
      "quic://${wgCfg.${wgIf}.topology.nodes.${nodeName}.ip}:22000"
    ] else [];

  # The interface on which to open firewall ports
  firewallInterface = wgIf;

  # Assertions specific to the WireGuard backend
  assertions = [
    {
      assertion = isValid;
      message = "Syncthing cluster backend is set to 'wireguard', but the specified interface '${wgIf}' is not defined in config.sensible.wireguard.";
    }
  ];
}
