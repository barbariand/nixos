{
  lib,
  pkgs,
  ...
}: {
  serverName,
  clientNames,
  externalDomain,
  listenPort ? 51820,
}: let
  nodes = lib.listToAttrs (lib.imap1 (i: name: {
    inherit name;
    value = {
      ip = "10.0.0.${toString i}";
      publicKey = "@PUBLIC_KEY_${lib.toUpper name}@";
    };
  }) ([serverName] ++ clientNames));

  mkServerModule = host: {
    networking.wireguard.interfaces.wg0 = {
      ips = ["${nodes.${host}.ip}/24"];
      listenPort = listenPort;
      privateKeyFile = "/etc/wireguard/private.key";

      postSetup = ''
        ${lib.getExe' pkgs.iptables "iptables"} -A FORWARD -i wg0 -j ACCEPT
        ${lib.getExe' pkgs.iptables "iptables"} -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      '';

      peers = lib.mapAttrsToList (name: peer: {
        publicKey = peer.publicKey;
        allowedIPs = ["${peer.ip}/32"];
      }) (lib.filterAttrs (n: v: n != host) nodes);
    };
    networking.nat = {
      enable = true;
      externalInterface = "eth0";
      internalInterfaces = ["wg0"];
    };
  };

  mkClientModule = host: {
    networking.wireguard.interfaces.wg0 = {
      ips = ["${nodes.${host}.ip}/24"];
      privateKeyFile = "/etc/wireguard/private.key";
      peers = [
        {
          publicKey = nodes.${serverName}.publicKey;
          allowedIPs = ["10.0.0.0/24"];
          endpoint = "${externalDomain}:${toString listenPort}";
          persistentKeepalive = 25;
        }
      ];
    };
  };
in
  lib.genAttrs ([serverName] ++ clientNames) (
    name:
      if name == serverName
      then mkServerModule name
      else mkClientModule name
  )
