{ config, lib, ... }:
with lib;
let
  cfg = config.sensible.nginx;
  atlasTypes = import ./types.nix { inherit lib; };
in {
  options.sensible.nginx = {
    enable = mkEnableOption "Sensible Nginx Ingress";
    inherit (atlasTypes.nginx) defaultRootResponse;
    virtualHosts = mkOption {
      type = types.attrsOf types.attrs;
      default = {};
      description = "Full exposure of Nginx virtualHosts.";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = cfg.virtualHosts;
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
