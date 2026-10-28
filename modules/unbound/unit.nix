{
  config,
  lib,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.unbound;

  formatARecord = fqdn: ip: let
    cleanFqdn = removeSuffix "." fqdn;
  in ''"${cleanFqdn}. IN A ${ip}"'';

  allZoneRecords = flatten (
    mapAttrsToList (_: zCfg: (mapAttrsToList formatARecord zCfg.records) ++ zCfg.rawLocalData) cfg.zones
  );

  localZoneDefs =
    mapAttrsToList (
      zName: zCfg: ''"${removeSuffix "." zName}." ${zCfg.zoneType}''
    )
    cfg.zones;

  insecureDomains = mapAttrsToList (zName: _: "${removeSuffix "." zName}.") (
    filterAttrs (_: zCfg: zCfg.insecure) cfg.zones
  );

  activeViews = filterAttrs (_: vCfg: vCfg.accessControl != []) cfg.views;

  useTls = cfg.enableDoT && cfg.acmeCert != null;
in
  {
    condition = cfg.enable;

    system = {
      services.unbound = {
        enable = true;
        settings = {
          server =
            {
              interface = cfg.listenInterfaces;
              access-control = map (net: "${net} allow") (unique cfg.accessControl);

              access-control-view = flatten (
                mapAttrsToList (
                  viewName: viewCfg: map (cidr: "${cidr} ${viewName}") viewCfg.accessControl
                )
                activeViews
              );

              local-zone =
                if builtins.length localZoneDefs == 1
                then head localZoneDefs
                else localZoneDefs;

              domain-insecure = insecureDomains;
              local-data = unique allZoneRecords;
            }
            // optionalAttrs useTls {
              tls-service-key = "/var/lib/acme/${cfg.acmeCert}/key.pem";
              tls-service-pem = "/var/lib/acme/${cfg.acmeCert}/fullchain.pem";
              tls-port = cfg.tlsPort;
            };

          view =
            mapAttrsToList (
              viewName: viewCfg:
                {
                  name = viewName;
                  local-data = unique ((mapAttrsToList formatARecord viewCfg.records) ++ viewCfg.localData);
                }
                // optionalAttrs (viewCfg.zone != null) {
                  local-zone = ''"${removeSuffix "." viewCfg.zone}." ${viewCfg.zoneType}'';
                }
            )
            activeViews;

          forward-zone = [
            {
              name = ".";
              forward-addr = cfg.resolvers;
            }
          ];
        };
      };

      systemd.services.unbound.serviceConfig =
        {
          ReadWritePaths = ["/var/lib/unbound"];
        }
        // optionalAttrs useTls {
          BindReadOnlyPaths = ["/var/lib/acme/${cfg.acmeCert}"];
        };

      users.users.unbound.extraGroups =
        optional useTls "acme" ++ optional config.services.nginx.enable "nginx";

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [53] ++ optional cfg.enableDoT cfg.tlsPort;
        allowedUDPPorts = [53] ++ optional cfg.enableDoT cfg.tlsPort;
      };
    };
  }
  |> sensibleLib.sensibleConfig
