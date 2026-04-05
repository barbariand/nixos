/*
# WireGuard Star Topology Utility
This module provides a helper function to build a server-client star topology
model using WireGuard. In this model, all traffic between clients (peers) is
routed through a central server, enabling peer-to-peer communication and
optional internet routing.

## Parameters
| Name            | Type             | Description                                                                                             |
|-----------------|------------------|---------------------------------------------------------------------------------------------------------|
| lib             | attrset          | The standard NixOS library (nixpkgs.lib).                                                               |
| port            | int              | The UDP port WireGuard will listen on (1-65535).                                                        |
| interface       | string           | The physical network interface (e.g., "eth0" or "enp1s0") used for WAN connectivity.                    |
| endpoint        | string           | The public domain or IP address of the server. The port is automatically appended for clients.          |
| privateKeyFile  | string (path)    | Absolute path to the WireGuard private key file on the local file system.                               |
| publicKey       | string (optional)| The server's public key. Required if clients (peers) are defined.                                       |
| ipBase          | string (IPv4)    | The base IPv4 address for the tunnel (default: "10.0.0.1"). Server gets this IP; peers get subsequent IPs.|
| peers           | attrset          | A mapping of peer names to their respective public keys. { client_name = "public_key"; }.               |
| serverName      | string           | Internal identifier for the server module in the returned attribute set (default: "server").            |
| tunnel          | string           | The name of the virtual WireGuard interface (default: "wg0").                                           |

## Key Generation
Before using this utility, you must generate keys on each machine.
Run the following command:
`wg genkey | sudo tee /etc/wireguard/private.key | wg pubkey`

1. Save the output (Public Key) to use in your Nix configuration.
2. Ensure the `privateKeyFile` parameter matches the path where you saved the
key.

## Usage
The function returns an attribute set containing NixOS modules.
One for the server (keyed by `serverName`) and one for each peer defined in the
`peers` set.

By using the function you implicitly create a tunnel between a abstract server
and a number of abstract peers.

### Bootstrap Phase (No Peers)
To generate keys initially, run the server without peers.
```nix
{ sensible-nix, nixpkgs, ... }:
let
  tunnel = import ./wireguard-util.nix {
    inherit (nixpkgs) lib;
    port = 51820;
    interface = "eth0";
    endpoint = "vpn.example.com";
    privateKeyFile = "/var/lib/wireguard/private.key";
  };
in {
  nixosConfigurations.server = nixpkgs.lib.nixosSystem {
    modules = [ tunnel.server ];
  };
}
```
#Full Configuration

Once keys are generated, populate the peers and publicKey fields.
```nix
{ sensible-nix, nixpkgs, ... }:
let
  tunnel = import ./wireguard-util.nix {
    inherit (nixpkgs) lib;
    port = 51820;
    interface = "eth0";
    endpoint = "vpn.example.com";
    publicKey = "SERVER_PUBLIC_KEY_HERE";
    privateKeyFile = "/etc/wireguard/private.key";
    peers = {
      laptop = "LAPTOP_PUBLIC_KEY_HERE";
      phone  = "PHONE_PUBLIC_KEY_HERE";
    };
  };
in {
  nixosConfigurations.server = nixpkgs.lib.nixosSystem {
    modules = [ tunnel.server ];
  };
  nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
    modules = [ tunnel.laptop ];
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
}:
assert lib.asserts.assertMsg (builtins.isString privateKeyFile) "privateKeyFile must be a path.";
assert lib.asserts.assertMsg (builtins.isInt port && port > 0 && port <= 65535) "The port number need to be between 1 and 65535.";
assert lib.asserts.assertMsg (builtins.isString interface) "The wifi interface you want to tunnel through.";
assert lib.asserts.assertMsg (builtins.isAttrs peers && (lib.lists.all (v: builtins.isString v) <| builtins.attrValues peers)) "peers should be an set with a name and a public key (string).";
assert lib.asserts.assertMsg (builtins.isString ipBase && builtins.match "^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$" ipBase != null) "The ipBase should be an ipv4 address.";
assert lib.asserts.assertMsg ((lib.lists.count (v: true) <| builtins.attrNames peers) > 0 -> builtins.isString publicKey) "Server public key is required for peers"; let
  ipParts = lib.strings.splitString "." ipBase;
  ipBase' = i: lib.strings.toInt (builtins.elemAt ipParts i);

  tunnelSubnet = "${builtins.toString (ipBase' 0)}.${builtins.toString (ipBase' 1)}.${builtins.toString (ipBase' 2)}.0/24";

  peerIPs =
    builtins.attrNames peers
    |> lib.lists.count (v: true)
    |> builtins.genList (i: "${builtins.toString (ipBase' 0)}.${builtins.toString (ipBase' 1)}.${builtins.toString (ipBase' 2)}.${builtins.toString (ipBase' 3 + i + 1)}/32");

  server = {
    boot.kernel.sysctl = {"net.ipv4.ip_forward" = true;};

    networking = {
      wireguard = {
        enable = true;
        useNetworkd = true;
        interfaces.${tunnel} = {
          privateKeyFile = privateKeyFile;
          listenPort = port;
          ips = ["${ipBase}/24"];

          peers =
            builtins.attrNames peers
            |> lib.lists.imap0 (i: name: {
              name = name;
              allowedIPs = [(builtins.elemAt peerIPs i)];
              publicKey = builtins.elemAt (builtins.attrValues peers) i;
            })
            |> builtins.filter (v: v.publicKey != null);
        };
      };

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

              iifname "${tunnel}" oifname "${tunnel}" counter accept
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
          ips = ["${lib.head (lib.splitString "/" ip)}/24"];
          peers = [
            {
              inherit publicKey;
              endpoint = "${endpoint}:${builtins.toString port}";
              name = serverName;
              allowedIPs = [tunnelSubnet];
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
      value = client (builtins.elemAt peerIPs i);
    })
    |> builtins.listToAttrs;
in
  {${serverName} = server;} // clients
