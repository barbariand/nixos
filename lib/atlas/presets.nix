{ lib }:
rec {
  mkCallable = baseAttrs:
    baseAttrs
    // {
      __functor = self: overrides:
        mkCallable (lib.recursiveUpdate (builtins.removeAttrs self ["__functor"]) overrides);
    };

  # Publik HTTPS-tjänst (publiceras i DDNS + Unbound + Nginx)
  mkPublic = proxyPass:
    mkCallable {
      enable = true;
      visibility = "public";
      nginx = {
        enable = true;
        inherit proxyPass;
      };
    };

  # Intern HTTPS-tjänst (begränsad till defaultInternal-zoner, exkluderad från DDNS)
  mkInternal = proxyPass:
    mkCallable {
      enable = true;
      visibility = "internal";
      nginx = {
        enable = true;
        inherit proxyPass;
      };
    };

  # Intern HTTPS-tjänst begränsad till specifika zoner (t.ex. ["wg_ollama" "wireguard" "lan"])
  mkZoneService = zones: proxyPass:
    mkCallable {
      enable = true;
      visibility = "internal";
      inherit zones;
      nginx = {
        enable = true;
        inherit proxyPass;
      };
    };

  # Endast DNS-post (och DDNS om visibility = "public"), utan Nginx-vhost
  mkDnsOnly = mkCallable {
    enable = true;
    visibility = "public";
    nginx.enable = false;
  };

  # L4-ström (TCP eller UDP) som automatiskt stänger av HTTP-vhost och öppnar brandväggen
  mkStream = protocol: port: backend:
    mkCallable {
      enable = true;
      visibility = "public";
      nginx.enable = false;
      streams.main = {
        inherit port protocol backend;
      };
    };

  mkTcpStream = port: backend:
    mkStream "tcp" port backend;

  mkUdpStream = port: backend:
    mkStream "udp" port backend;

  mkStreams = streams:
    mkCallable {
      enable = true;
      visibility = "public";
      nginx.enable = false;
      inherit streams;
    };

  # Regelbyggare för hela subdomänmönster (t.ex. "*.internal")
  mkRule = attrs: mkCallable attrs;
}
