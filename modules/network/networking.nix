{
  config,
  lib,
  ...
}: {
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = "opportunistic";
      FallbackDNS = [
        "1.1.1.1"
        "9.9.9.9"
      ];
    };
  };
  networking.nameservers = ["1.1.1.1"];

  systemd.services.systemd-networkd.serviceConfig= {
    LoadCredential = lib.mkForce [];
    LoadCredentialEncrypted = lib.mkForce [];
    SetCredential = lib.mkForce [];
    SetCredentialEncrypted = lib.mkForce [];
    };
}
