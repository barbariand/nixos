{ lib, subdomainsLib }:
let
  ipLib = import ../wireguard/ip.nix { inherit lib; };
in
{
  mkAssertions = atlasCfg: let
    activeSubs = subdomainsLib.resolveAllSubdomains atlasCfg;

    zoneAssertions = lib.flatten (lib.mapAttrsToList (subName: sub:
      map (zName: {
        assertion = builtins.hasAttr zName atlasCfg.zones;
        message = "sensible.atlas: Subdomain '${subName}' references unknown zone '${zName}'.";
      }) sub.zones
    ) activeSubs);

    zoneIpAssertions = lib.mapAttrsToList (zName: zCfg: {
      assertion = zCfg.ip == null || ipLib.isValidIPv4 zCfg.ip;
      message = "sensible.atlas: Zone '${zName}' has an invalid IPv4 address '${toString zCfg.ip}'.";
    }) atlasCfg.zones;

    allStreams = lib.attrValues (subdomainsLib.resolveNginxStreams activeSubs);
    tcpStreamPorts = map (s: s.port) (builtins.filter (s: s.protocol == "tcp") allStreams);
    udpStreamPorts = map (s: s.port) (builtins.filter (s: s.protocol == "udp") allStreams);
  in [
    {
      assertion = atlasCfg.baseDomain != "";
      message = "sensible.atlas: 'baseDomain' must not be empty.";
    }
    {
      assertion = ipLib.isValidIPv4 atlasCfg.serverIp;
      message = "sensible.atlas: 'serverIp' (${atlasCfg.serverIp}) is not a valid IPv4 address.";
    }
    {
      assertion = (builtins.length tcpStreamPorts) == (builtins.length (lib.unique tcpStreamPorts));
      message = "sensible.atlas: Duplicate TCP stream listen ports detected across active subdomains.";
    }
    {
      assertion = (builtins.length udpStreamPorts) == (builtins.length (lib.unique udpStreamPorts));
      message = "sensible.atlas: Duplicate UDP stream listen ports detected across active subdomains.";
    }
  ] ++ zoneAssertions ++ zoneIpAssertions;
}
