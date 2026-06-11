{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sensible.atlas;

  # Bygg access control list för interna tjänster
  internalAcls = concatMapStringsSep "\n" (net: "allow ${net};") cfg.internalNetworks + "\ndeny all;";

  # Extrahera och bygg alla streams
  streamList = flatten (mapAttrsToList (
    subName: sub:
      mapAttrsToList (streamName: streamCfg: {
        upstreamName = "${subName}_${streamName}_backend";
        inherit (streamCfg) port protocol backend;
      })
      sub.streams
  ) (filterAttrs (n: s: s.enable) cfg.subdomains));

  buildUpstream = s: ''
    upstream ${s.upstreamName} {
      server ${s.backend};
    }
  '';

  buildServer = s: ''
    server {
      listen ${toString s.port}${
      if s.protocol == "udp"
      then " udp"
      else ""
    };
      proxy_pass ${s.upstreamName};
    }
  '';

  generatedStreamConfig =
    if streamList == []
    then ""
    else ''
      stream {
        ${concatMapStringsSep "\n" buildUpstream streamList}
        ${concatMapStringsSep "\n" buildServer streamList}
      }
    '';
in {
  config = mkIf (cfg.enable && cfg.nginx.enable) {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Kombinera användarens eventuella appendConfig med genererade streams
      appendConfig = cfg.nginx.appendConfig + "\n" + generatedStreamConfig;

      virtualHosts = let
        activeSubs = filterAttrs (n: s: s.enable && s.nginx.enable) cfg.subdomains;
        generatedHosts = mapAttrs' (name: sub:
          nameValuePair "${name}.${cfg.baseDomain}" {
            useACMEHost = mkIf cfg.acme.enable cfg.baseDomain;
            forceSSL = true;

            # Injektera ACL om visibility är "internal"
            extraConfig =
              sub.nginx.extraConfig
              + (optionalString (sub.visibility == "internal") "\n${internalAcls}\n");

            locations."/" = mkIf (sub.nginx.proxyPass != null) {
              proxyPass = sub.nginx.proxyPass;
              proxyWebsockets = true;
            };
          })
        activeSubs;
      in
        {
          "_" = {
            default = true;
            useACMEHost = mkIf cfg.acme.enable cfg.baseDomain;
            addSSL = true;
            locations."/".return = cfg.nginx.defaultRootResponse;
          };
        }
        // generatedHosts;
    };
    networking.firewall.allowedTCPPorts = [80 443];
  };
}
