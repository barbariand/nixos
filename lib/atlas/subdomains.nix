{ lib }:
rec {
  # Matchar glob-mönster (t.ex. "*", "*.internal", "minecraft.*", "exact")
  matchPattern = pattern: name: let
    regex = "^" + (builtins.replaceStrings ["." "*"] ["\\." ".*"] pattern) + "$";
  in
    builtins.match regex name != null;

  # Plattar ut nästlade subdomäner rekursivt och låter barn ärva förälderns policy
  flattenSubdomains = parentPrefix: parentPolicy: subdomainsAttr:
    lib.foldlAttrs (acc: name: subCfg: let
      fullName =
        if parentPrefix == ""
        then name
        else if (subCfg.childNaming or "subdomain") == "prefix"
        then "${parentPrefix}.${name}"
        else "${name}.${parentPrefix}";

      inherited = {
        visibility =
          if (subCfg.visibility or null) != null
          then subCfg.visibility
          else parentPolicy.visibility or "public";
        zones =
          if (subCfg.zones or []) != []
          then subCfg.zones
          else parentPolicy.zones or [];
        allowNetworks = lib.unique ((parentPolicy.allowNetworks or []) ++ (subCfg.allowNetworks or []));
        denyNetworks = lib.unique ((parentPolicy.denyNetworks or []) ++ (subCfg.denyNetworks or []));
      };

      effectiveSelf = subCfg // inherited;
      children = flattenSubdomains fullName effectiveSelf (subCfg.subdomains or {});
    in
      acc // { ${fullName} = effectiveSelf; } // children
    ) {} subdomainsAttr;

  # Applicerar matchande regler från sensible.atlas.rules på en subdomän
  applyRules = rules: subName: subCfg: let
    matchingRules = lib.attrValues (lib.filterAttrs (pattern: _: matchPattern pattern subName) rules);

    mergedRule = lib.foldl' (acc: r: {
      visibility = if r.visibility != null then r.visibility else acc.visibility;
      zones = lib.unique (acc.zones ++ r.zones);
      allowNetworks = lib.unique (acc.allowNetworks ++ r.allowNetworks);
      denyNetworks = lib.unique (acc.denyNetworks ++ r.denyNetworks);
      ddnsEnable = if r.ddns.enable != null then r.ddns.enable else acc.ddnsEnable;
      unboundEnable = if r.unbound.enable != null then r.unbound.enable else acc.unboundEnable;
      nginxEnable = if r.nginx.enable != null then r.nginx.enable else acc.nginxEnable;
      extraConfig =
        acc.extraConfig
        + (lib.optionalString (r.nginx.extraConfig != "") "\n${r.nginx.extraConfig}");
      extraHeaders = acc.extraHeaders // r.nginx.extraHeaders;
      allowedTCPPorts = lib.unique (acc.allowedTCPPorts ++ r.firewall.allowedTCPPorts);
      allowedUDPPorts = lib.unique (acc.allowedUDPPorts ++ r.firewall.allowedUDPPorts);
    }) {
      visibility = null;
      zones = [];
      allowNetworks = [];
      denyNetworks = [];
      ddnsEnable = null;
      unboundEnable = null;
      nginxEnable = null;
      extraConfig = "";
      extraHeaders = {};
      allowedTCPPorts = [];
      allowedUDPPorts = [];
    } matchingRules;

    effectiveProxyPass =
      if subCfg.proxyPass != null
      then subCfg.proxyPass
      else subCfg.nginx.proxyPass;

    effectiveVisibility =
      if subCfg.visibility != null
      then subCfg.visibility
      else if mergedRule.visibility != null
      then mergedRule.visibility
      else "public";

    effectiveNginxEnable =
      if subCfg.nginx.enable != null
      then subCfg.nginx.enable
      else if mergedRule.nginxEnable != null
      then mergedRule.nginxEnable
      else (effectiveProxyPass != null || subCfg.streams == {});

    effectiveDdnsEnable =
      if subCfg.ddns.enable != null
      then subCfg.ddns.enable
      else if subCfg.cloudflare.enable != null
      then subCfg.cloudflare.enable
      else if mergedRule.ddnsEnable != null
      then mergedRule.ddnsEnable
      else true;

    effectiveUnboundEnable =
      if subCfg.unbound.enable != null
      then subCfg.unbound.enable
      else if mergedRule.unboundEnable != null
      then mergedRule.unboundEnable
      else true;
  in {
    enable = subCfg.enable;
    visibility = effectiveVisibility;
    ip = subCfg.ip;
    zones = lib.unique (mergedRule.zones ++ subCfg.zones);
    allowNetworks = lib.unique (mergedRule.allowNetworks ++ subCfg.allowNetworks);
    denyNetworks = lib.unique (mergedRule.denyNetworks ++ subCfg.denyNetworks);
    ddns.enable = effectiveDdnsEnable;
    unbound.enable = effectiveUnboundEnable;
    nginx = {
      enable = effectiveNginxEnable;
      proxyPass = effectiveProxyPass;
      websockets = subCfg.nginx.websockets;
      extraHeaders = mergedRule.extraHeaders // subCfg.nginx.extraHeaders;
      extraConfig =
        lib.concatStringsSep "\n" (builtins.filter (s: s != "") [
          mergedRule.extraConfig
          subCfg.nginx.extraConfig
        ]);
    };
    streams = subCfg.streams;
    firewall = {
      allowedTCPPorts = lib.unique (mergedRule.allowedTCPPorts ++ subCfg.firewall.allowedTCPPorts);
      allowedUDPPorts = lib.unique (mergedRule.allowedUDPPorts ++ subCfg.firewall.allowedUDPPorts);
    };
  };

  resolveAllSubdomains = atlasCfg: let
    rawFlattened = flattenSubdomains "" {} atlasCfg.subdomains;
    resolved = lib.mapAttrs (subName: subCfg: applyRules atlasCfg.rules subName subCfg) rawFlattened;
  in
    lib.filterAttrs (_: s: s.enable) resolved;

  # Beräknar vilka zoner en subdomän tillhör
  effectiveZonesForSub = atlasCfg: sub: let
    defaultZoneNames = builtins.attrNames (lib.filterAttrs (_: z: z.defaultInternal) atlasCfg.zones);
  in
    if sub.zones != []
    then sub.zones
    else defaultZoneNames;

  # Beräknar tillåtna CIDR-nätverk för en intern subdomän i Nginx
  resolveAllowedCidrs = atlasCfg: sub: let
    zoneNames = effectiveZonesForSub atlasCfg sub;
    zoneCidrs = lib.concatMap (zName: atlasCfg.zones.${zName}.cidrs or []) zoneNames;
    fallbackInternal =
      if atlasCfg.zones == {}
      then atlasCfg.internalNetworks
      else [];
  in
    if sub.visibility == "internal"
    then lib.unique (zoneCidrs ++ fallbackInternal ++ sub.allowNetworks)
    else sub.allowNetworks;

  # Bygger Nginx virtualHosts
  resolveNginxVirtualHosts = atlasCfg: activeSubs:
    lib.mapAttrs' (subName: sub:
      lib.nameValuePair "${subName}.${atlasCfg.baseDomain}" {
        enable = true;
        proxyPass = sub.nginx.proxyPass;
        websockets = sub.nginx.websockets;
        forceSSL = true;
        acmeHost = if atlasCfg.acme.enable then atlasCfg.baseDomain else null;
        allowNetworks = resolveAllowedCidrs atlasCfg sub;
        denyNetworks = sub.denyNetworks;
        extraHeaders = sub.nginx.extraHeaders;
        extraConfig = sub.nginx.extraConfig;
      }
    ) (lib.filterAttrs (_: s: s.nginx.enable) activeSubs);

  # Bygger Nginx L4-streams
  resolveNginxStreams = activeSubs:
    lib.foldlAttrs (acc: subName: sub:
      acc
      // (lib.mapAttrs' (streamName: streamCfg:
        lib.nameValuePair "${builtins.replaceStrings ["."] ["_"] subName}_${streamName}" {
          enable = true;
          inherit (streamCfg) port protocol backend;
          openFirewall = true;
        }
      ) sub.streams)
    ) {} activeSubs;

  # Bygger DDNS-domänlistan
  resolveDdnsDomains = atlasCfg: activeSubs: let
    publicSubs = lib.filterAttrs (_: s: s.ddns.enable && s.visibility == "public") activeSubs;
  in
    [atlasCfg.baseDomain]
    ++ (lib.mapAttrsToList (subName: _: "${subName}.${atlasCfg.baseDomain}") publicSubs);

  # Bygger Unbound access-control-lista
  resolveUnboundAccessControl = atlasCfg: let
    zoneCidrs = lib.concatMap (z: z.cidrs) (lib.attrValues atlasCfg.zones);
  in
    lib.unique (
      ["127.0.0.0/8"]
      ++ atlasCfg.internalNetworks
      ++ zoneCidrs
    );

  # Bygger Unbound baszon-records
  resolveUnboundBaseRecords = atlasCfg: activeSubs: let
    unboundSubs = lib.filterAttrs (_: s: s.unbound.enable) activeSubs;
    subRecords = lib.mapAttrs' (subName: sub:
      lib.nameValuePair "${subName}.${atlasCfg.baseDomain}" (if sub.ip != null then sub.ip else atlasCfg.serverIp)
    ) unboundSubs;
  in
    { "${atlasCfg.baseDomain}" = atlasCfg.serverIp; } // subRecords;

  # Bygger Unbound Split-Horizon-vyer från både zones och manuella dns.views
  resolveUnboundViews = atlasCfg: activeSubs: let
    unboundSubs = lib.filterAttrs (_: s: s.unbound.enable) activeSubs;

    # Generera vyer automatiskt för alla zoner som har en egen IP skild från serverIp
    zoneViews = lib.mapAttrs (zName: zCfg: let
      targetIp = if zCfg.ip != null then zCfg.ip else atlasCfg.serverIp;
      matchingSubs = lib.filterAttrs (_: sub:
        sub.nginx.enable
        && (
          (sub.zones != [] && builtins.elem zName sub.zones)
          || (sub.zones == [] && zCfg.defaultInternal)
        )
      ) unboundSubs;
      records = lib.mapAttrs' (subName: _:
        lib.nameValuePair "${subName}.${atlasCfg.baseDomain}" targetIp
      ) matchingSubs;
    in {
      accessControl = zCfg.cidrs;
      zone = atlasCfg.baseDomain;
      inherit records;
      localData = zCfg.extraLocalData or [];
    }) (lib.filterAttrs (_: zCfg: zCfg.ip != null && zCfg.ip != atlasCfg.serverIp) atlasCfg.zones);

    # Slå samman med eventuella manuellt deklarerade dns.views
    manualViews = lib.mapAttrs (_: vCfg: {
      accessControl = vCfg.accessControl;
      zone = atlasCfg.baseDomain;
      records = vCfg.records or {};
      localData = vCfg.localData or [];
    }) atlasCfg.dns.views;
  in
    lib.recursiveUpdate zoneViews manualViews;

  # Sammanställer extra brandväggsportar från subdomäner och global atlas-konfiguration
  resolveExtraFirewall = atlasCfg: activeSubs: {
    allowedTCPPorts = lib.unique (
      atlasCfg.firewall.allowedTCPPorts
      ++ (lib.concatMap (s: s.firewall.allowedTCPPorts) (lib.attrValues activeSubs))
    );
    allowedUDPPorts = lib.unique (
      atlasCfg.firewall.allowedUDPPorts
      ++ (lib.concatMap (s: s.firewall.allowedUDPPorts) (lib.attrValues activeSubs))
    );
  };
}
