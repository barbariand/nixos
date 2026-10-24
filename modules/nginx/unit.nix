{
  config,
  lib,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.nginx;

  activeVhosts = filterAttrs (_: v: v.enable) cfg.virtualHosts;
  activeStreams = filterAttrs (_: s: s.enable) cfg.streams;

  mkAclBlock = vhost: let
    denies = map (cidr: "deny ${cidr};") vhost.denyNetworks;
    allows =
      if vhost.allowNetworks != []
      then (map (cidr: "allow ${cidr};") vhost.allowNetworks) ++ ["deny all;"]
      else [];
  in
    concatStringsSep "\n" (denies ++ allows);

  mkHeaderBlock = vhost:
    concatStringsSep "\n" (mapAttrsToList (k: v: ''add_header ${k} "${v}" always;'') vhost.extraHeaders);

  generatedVhosts = mapAttrs (_: vhost: let
    certHost = if vhost.acmeHost != null then vhost.acmeHost else cfg.acmeCert;
    aclConfig = mkAclBlock vhost;
    headerConfig = mkHeaderBlock vhost;
  in {
    useACMEHost = mkIf (certHost != null) certHost;
    forceSSL = vhost.forceSSL && (certHost != null);
    extraConfig = concatStringsSep "\n" (filter (s: s != "") [
      aclConfig
      headerConfig
      vhost.extraConfig
    ]);
    locations."/" = mkIf (vhost.proxyPass != null) {
      proxyPass = vhost.proxyPass;
      proxyWebsockets = vhost.websockets;
    };
  }) activeVhosts;

  streamList = mapAttrsToList (name: sCfg: {
    upstreamName = "${replaceStrings ["." "-"] ["_" "_"] name}_backend";
    inherit (sCfg) port protocol backend openFirewall;
  }) activeStreams;

  buildUpstream = s: ''
    upstream ${s.upstreamName} {
      server ${s.backend};
    }
  '';

  buildServer = s: ''
    server {
      listen ${toString s.port}${optionalString (s.protocol == "udp") " udp"};
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

  streamTcpPorts = map (s: s.port) (filter (s: s.openFirewall && s.protocol == "tcp") streamList);
  streamUdpPorts = map (s: s.port) (filter (s: s.openFirewall && s.protocol == "udp") streamList);
in
  {
    condition = cfg.enable;

    system = {
      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        appendConfig = concatStringsSep "\n" (filter (s: s != "") [
          cfg.appendConfig
          generatedStreamConfig
        ]);
        virtualHosts =
          {
            "_" = {
              default = true;
              useACMEHost = mkIf (cfg.acmeCert != null) cfg.acmeCert;
              addSSL = cfg.acmeCert != null;
              locations."/".return = cfg.defaultRootResponse;
            };
          }
          // generatedVhosts;
      };

      networking.firewall = {
        allowedTCPPorts = (optional cfg.openFirewall 80) ++ (optional cfg.openFirewall 443) ++ streamTcpPorts;
        allowedUDPPorts = streamUdpPorts;
      };
    };
  }
  |> sensibleLib.sensibleConfig
