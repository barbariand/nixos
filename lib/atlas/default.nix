{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.sensible.atlas;
  activeSubs = filterAttrs (n: s: s.enable) cfg.subdomains;
in {
  imports = [
    ./nginx.nix
    ./unbound.nix
  ];

  options.sensible.atlas = {
    enable = mkEnableOption "Sensible Atlas";
    baseDomain = mkOption { type = types.str; };
    serverIp = mkOption { type = types.str; };

    subdomains = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "subdomain";
          proxyPass = mkOption { type = types.nullOr types.str; default = null; };
          extraConfig = mkOption { type = types.lines; default = ""; };
        };
      });
      default = {};
    };
  };

  config = mkIf cfg.enable {
    # 1. Konfigurera Nginx via Atlas
    sensible.atlas.nginx = {
      enable = mkDefault true;
      virtualHosts = mapAttrs (name: sub: {
        forceSSL = true;
        locations."/" = mkIf (sub.proxyPass != null) {
          proxyPass = sub.proxyPass;
          proxyWebsockets = true;
        };
        extraConfig = sub.extraConfig;
      }) activeSubs;
    };

    # 2. Konfigurera Unbound via Atlas
    sensible.atlas.unbound = {
      enable = mkDefault true;
      inherit (cfg) baseDomain serverIp;
      localRecords = mapAttrs (name: sub: cfg.serverIp) activeSubs;
      tls = {
        enable = mkDefault config.security.acme.acceptTerms;
        certPath = "/var/lib/acme/${cfg.baseDomain}/fullchain.pem";
        keyPath = "/var/lib/acme/${cfg.baseDomain}/key.pem";
      };
    };
  };
}
