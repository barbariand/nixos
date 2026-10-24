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
}
