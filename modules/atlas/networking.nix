{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.atlas;

  activeSubs = filterAttrs (n: s: s.enable) cfg.subdomains;

  tcpPorts =
    concatMap (
      s:
        s.firewall.allowedTCPPorts
        ++ (mapAttrsToList (_: st: st.port) (filterAttrs (_: st: st.protocol == "tcp") s.streams))
    ) (attrValues activeSubs)
    ++ cfg.firewall.allowedTCPPorts;

  udpPorts =
    concatMap (
      s:
        s.firewall.allowedUDPPorts
        ++ (mapAttrsToList (_: st: st.port) (filterAttrs (_: st: st.protocol == "udp") s.streams))
    ) (attrValues activeSubs)
    ++ cfg.firewall.allowedUDPPorts;
in {
  config = mkIf cfg.enable {
    networking.nameservers = mkForce cfg.dns.resolvers;

    services.resolved = mkForce {
      enable = true;
      settings.Resolve = {
        fallbackDNS = cfg.dns.resolvers;
        DNSStubListener = false;
      };
    };

    networking.firewall.allowedTCPPorts = tcpPorts;
    networking.firewall.allowedUDPPorts = udpPorts;
  };
}
