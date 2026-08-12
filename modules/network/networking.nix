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
  systemd.network.networks."40-wg0" = {
    matchConfig.Name = "wg0";
    networkConfig = {
      DNS = "10.55.0.1#dns.simd.me";
      Domains = "~internal.simd.me homepage.simd.me grafana.simd.me logs.simd.me";
    };
  };
}
