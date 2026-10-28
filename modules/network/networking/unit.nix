{
  config,
  lib,
  sensibleLib,
  ...
}: let
  cfg = config.sensible.networking;
  unboundActive = config.sensible.unbound.enable or false;
in
  {
    condition = cfg.enable;

    system = {
      networking.nameservers = cfg.nameservers;

      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNSOverTLS = lib.mkIf (!unboundActive) cfg.dnsOverTls;
          FallbackDNS = cfg.fallbackDns;
          DNSStubListener =
            if unboundActive
            then false
            else true;
        };
      };

      systemd.services.systemd-networkd.serviceConfig = {
        LoadCredential = lib.mkForce [];
        LoadCredentialEncrypted = lib.mkForce [];
        SetCredential = lib.mkForce [];
        SetCredentialEncrypted = lib.mkForce [];
      };
    };
  }
  |> sensibleLib.sensibleConfig
