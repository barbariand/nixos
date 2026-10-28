{
  config,
  lib,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.acme;

  mappedCerts =
    mapAttrs (_: certCfg: {
      domain = certCfg.domain;
      extraDomainNames = unique (
        (optional certCfg.wildcard "*.${certCfg.domain}") ++ certCfg.extraDomainNames
      );
      dnsProvider =
        if certCfg.dnsProvider != null
        then certCfg.dnsProvider
        else cfg.dnsProvider;
      environmentFile =
        if certCfg.environmentFile != null
        then certCfg.environmentFile
        else cfg.environmentFile;
      webroot = certCfg.webroot;
      group =
        if certCfg.group != null
        then certCfg.group
        else cfg.group;
      reloadServices = unique (cfg.reloadServices ++ certCfg.reloadServices);
    })
    cfg.certs;
in
  {
    condition = cfg.enable;

    assertions = [
      {
        assertion = cfg.email != "";
        message = "sensible.acme: 'email' must be set when ACME is enabled.";
      }
      {
        assertion = all (c: c.webroot != null || c.environmentFile != null) (attrValues mappedCerts);
        message = "sensible.acme: Every DNS-01 certificate must have an 'environmentFile' configured.";
      }
    ];

    system = {
      security.acme = {
        acceptTerms = cfg.acceptTerms;
        defaults = {
          email = cfg.email;
          dnsResolver = cfg.dnsResolver;
          group = cfg.group;
          dnsProvider = cfg.dnsProvider;
          environmentFile = cfg.environmentFile;
          webroot = null;
          reloadServices = unique cfg.reloadServices;
        };
        certs = mappedCerts;
      };
    };
  }
  |> sensibleLib.sensibleConfig
