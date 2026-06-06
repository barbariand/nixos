{
  config,
  lib,
  ...
}: {
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = "opportunistic";
      Domains = ["~."];
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
      ];
    };
  };
  networking.nameservers = ["192.168.1.3#dns.simd.me" "1.1.1.1"];
}
