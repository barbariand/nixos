/*
# Utility to build a server-client type wireguard tunnel to access home network
NOTE: This is still p2p, but it is not designed to work symmetrically

## Parameters
| name         | type                        | description                                                                                                 |
------------------------------------------------------------------------------------------------------------------------------------------------------------
| lib          | attrset                     | Nixos standard library.                                                                                     |
| port         | port number                 | This number correspond to the port that wireguard should listen to.                                         |
| interface    | string                      | The network interface that should be used by wireguard.                                                     |
| endpoint     | string                      | A domain or ip address that allows the peer to connect to your server. Port is automatically appended.      |
| publicKey    | string                      | The servers public key. Generated from the private key that is automatically generated.                     |
| ipBase       | ipv4 string                 | The ipv4 address that will be assigned to the server and peers will come directly after the server address. |
| peers        | name and public key attrset | An attribute set with peer names connected to their public key or null.                                     |
| serverName   | string                      | customizable name of internal representation of the server.                                                 |
| tunnel       | string                      | Name of tunnel.                                                                                             |
| use_nftables | bool                        | Override the usage of iptables with nftables and automatically setup the firewall.                          |

## Description
Create a tight wireguard configuration to be deployed across multiple machines.
Singular server multiple clients model.

## Usage
NOTE: To allow generation of public/private key on the server, omit peers and
(optionally) publicKey.

NOTE: Nixos lib can be acquired from the flake through
the input nixpkgs by calling nixpkgs.lib.

By using the function you implicitly create a tunnel between a abstract server
and a number of abstract peers.

The function will return a set with modules definitions for each peer and the
server.

## Example output of flake

```nix
{ nixpkgs, ... }: let
  tunnel = build_wireguard_tunnel {
    lib = nixpkgs.lib;
    port = 51820;
    interface = "eth0";
    endpoint = "myhome.com";
    publicKey = "...";
    peers = {
      client_1 = "...";
      ...
    };
  };
in {
  nixosConfigurations = {
    server = nixpkgs.lib.nixosSystem {
      modules = [ tunnel.server ];
      ...
    };
    my_laptop = nixpkgs.lib.nixosSystem {
      modules = [ tunnel.client_1 ];
      ...
    };
    ...
  };
}
```

## Example server without peers

This should be the primary state of the tunnel to allow bootstrapping the
server and generate the necessary keys.

```nix
{ nixpkgs, ... }: let
  tunnel = build_wireguard_tunnel {
    lib = nixpkgs.lib;
    port = 51820;
    interface = "eth0";
    endpoint = "myhome.com";
  };
in {
  nixosConfigurations = {
    server = nixpkgs.lib.nixosSystem {
      modules = [ tunnel.server ];
      ...
    };
    ...
  };
}
```
*/
{
  lib,
  port,
  interface,
  endpoint,
  privateKeyFile,
  publicKey ? null,
  ipBase ? "10.0.0.1",
  peers ? {},
  serverName ? "server",
  tunnel ? "wg0",
  use_nftables ? true,
}:
assert lib.asserts.assertMsg (builtins.isString privateKeyFile) "privateKeyFile must be a path.";
assert lib.asserts.assertMsg (builtins.isInt port && port > 0 && port <= 65535) "The port number need to be between 1 and 65535.";
assert lib.asserts.assertMsg (builtins.isString interface) "The wifi interface you want to tunnel through.";
assert lib.asserts.assertMsg (builtins.isAttrs peers && (lib.lists.all (v: builtins.isString v) <| builtins.attrValues peers)) "peers should be an set with a name and a public key (string).";
assert lib.asserts.assertMsg (builtins.isString ipBase && builtins.match "^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$" ipBase != null) "The ipBase should be an ipv4 address.";
assert lib.asserts.assertMsg ((lib.lists.count (v: true) <| builtins.attrNames peers) > 0 -> builtins.isString publicKey) "Server public key is required for peers"; let
  ipBase' = i: let
    rawValues = lib.strings.splitString "." ipBase;
    values = map (section: lib.strings.toInt section) rawValues;
  in
    assert lib.lists.count (v: true) values == 4;
    assert lib.lists.all (v: v < 255) values;
    # FIXME: allow handling more than 253 peers on the tunnel network.
    assert lib.asserts.assertMsg ((lib.lists.count (v: true) <| builtins.attrNames peers) < (253 - builtins.elemAt values 3)) "Too many peers, can only handle 253 peers per tunnel.";
      builtins.elemAt values i;
  peerIPs = builtins.attrNames peers |> lib.lists.count (v: true) |> builtins.genList (i: "${builtins.toString <| ipBase' 0}.${builtins.toString <| ipBase' 1}.${builtins.toString <| ipBase' 2}.${builtins.toString <| (ipBase' 3) + i + 1}/32");
  server = {
    boot.kernel.sysctl = {"net.ipv4.ip_forward" = true;};
    networking = {
      wireguard = {
        enable = true;
        useNetworkd = true;
        interfaces.${tunnel} = {
          privateKeyFile = privateKeyFile;
          listenPort = port;
          # IP that the client need to allow access to.
          ips = [
            "${ipBase}/32"
          ];
          # Peers that should be allowed to access the server.
          peers =
            builtins.attrNames peers
            |> lib.lists.imap0 (
              i: name: {
                name = name;
                allowedIPs = [(builtins.elemAt peerIPs i)];
                publicKey = builtins.elemAt (builtins.attrValues peers) i;
              }
            )
            |> builtins.filter (v: v.publicKey != null);
        };
      };
      # Allow access through the firewall and enable masquarading of the IP addresses.
      firewall.allowedUDPPorts = [port];
      nftables = {
        enable = true;
        flushRuleset = true;
        ruleset = ''
          table inet filter {
            chain forward {
              type filter hook forward priority filter; policy accept;
              ct state established,related accept
              iifname "${tunnel}" oifname "${interface}" counter accept
            }
          }

          table inet nat {
            chain postrouting {
              type nat hook postrouting priority srcnat;
              oifname "${interface}" counter masquerade
            }
          }
        '';
      };
    };
  };
  client = ip: {
    networking = {
      firewall.allowedUDPPorts = [port];
      wireguard = {
        enable = true;
        useNetworkd = true;
        interfaces.${tunnel} = {
          privateKeyFile = privateKeyFile;
          ips = [ip];
          peers = [
            {
              inherit publicKey;
              endpoint = "${endpoint}:${builtins.toString port}";
              name = serverName;
              allowedIPs = [ipBase];
              persistentKeepalive = 21;
            }
          ];
        };
      };
    };
  };
  clients =
    builtins.attrNames peers
    |> lib.lists.imap0 (i: name: {
      name = name;
      value = client <| builtins.elemAt peerIPs i;
    })
    |> builtins.listToAttrs;
in
  {${serverName} = server;} // clients
