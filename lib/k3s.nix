
/*
# K3s Cluster Utility
This module provides a helper function to build a K3s (Kubernetes) cluster
with an explicit controller and a set of worker nodes. It enforces
network-level constraints and separates server-side orchestration from
agent-side execution.

## Parameters
| Name                     | Type             | Description                                                                                             |
|--------------------------|------------------|---------------------------------------------------------------------------------------------------------|
| lib                      | attrset          | The standard NixOS library (nixpkgs.lib).                                                               |
| nodes                    | attrset          | A mapping of worker node names to their config: { worker1 = { ip = "10.55.0.2"; }; }.                  |
| controllerHostname       | string           | The hostname for the master node.                                                                       |
| controllerIp             | string (IPv4)    | The IPv4 address of the controller within the cluster network.                                          |
| tokenFileFn              | function         | A function taking 'config' and returning the path to the K3s secret (e.g., config: config.age.path...). |
| controllerIsSchedulable  | bool             | If true (default), the controller also acts as a worker node.                                           |
| controllerDisableTraefik | bool             | If true, disables the built-in Traefik ingress controller on the server.                                |
| clusterInterface         | string (optional)| The network interface to bind (e.g., "wg0"). If provided, k3s waits for this interface.                 |
| globalExtraFlags         | string           | Flags applied to all nodes in the cluster.                                                              |
| controllerExtraFlags     | string           | Flags applied only to the controller node.                                                              |

## Usage
The function returns an attribute set containing NixOS modules. One module is
generated for the controller (using `controllerHostname`) and one for each
entry in the `nodes` set.

### Example with Agenix (Dynamic Token Path)
```
{ sensible-nix, nixpkgs, ... }:
let
  cluster = import ./k3s-cluster.nix {
    inherit (nixpkgs) lib;
    controllerHostname = "raspberrypi";
    controllerIp = "10.55.0.1";
    clusterInterface = "wg0";
    # Dynamically fetch path from age secrets
    tokenFileFn = config: config.age.secrets.k3s-token.path;
    nodes = {
      server_one = { ip = "10.55.0.4"; };
    };
  };
in {
  nixosConfigurations.raspberrypi = nixpkgs.lib.nixosSystem {
    modules = [ cluster.raspberrypi ];
  };
  nixosConfigurations.server_one = nixpkgs.lib.nixosSystem {
    modules = [ cluster.server_one ];
  };
}
```
*/
{
  lib,
  nodes ? {},
  controllerHostname,
  controllerIp,
  tokenFileFn,
  controllerIsSchedulable ? true,
  controllerDisableTraefik ? false,
  clusterInterface ? null,
  globalExtraFlags ? "",
  controllerExtraFlags ? "",
}: let
  # --- IP Validation Helper ---
  isValidIPv4 = ip: let
    parts = lib.strings.splitString "." ip;
    isByte = s: let
      isNumeric = builtins.match "[0-9]+" s != null;
      n =
        if isNumeric
        then lib.strings.toInt s
        else null;
    in
      n != null && n >= 0 && n <= 255;
  in
    (builtins.length parts == 4) && (lib.all isByte parts);

  # --- Global Assertions ---
  globalCheck = assert lib.asserts.assertMsg (builtins.isString controllerHostname) "controllerHostname must be a string.";
  assert lib.asserts.assertMsg (isValidIPv4 controllerIp) "The controller IP '${controllerIp}' is invalid.";
  assert lib.asserts.assertMsg (builtins.isFunction tokenFileFn) "tokenFileFn must be a function that accepts 'config'.";
  assert lib.asserts.assertMsg (!(lib.hasAttr controllerHostname nodes))
  "The controller '${controllerHostname}' cannot exist in the 'nodes' set to avoid logic collisions."; true;

  # --- Base K3s Flags Generator ---
  # Generates the default flags for any node
  mkDefaultFlags = ip:
    lib.concatStringsSep " " (builtins.filter (s: s != "") [
      "--node-ip ${ip}"
      "--node-external-ip ${ip}"
      (
        if clusterInterface != null
        then "--flannel-iface ${clusterInterface}"
        else ""
      )
      globalExtraFlags
    ]);

  # --- Base K3s Module Template ---
  mkBaseModule = {
    name,
    ip,
    role,
    config,
    extraFlags ? "",
  }: {
    assertions = [
      {
        assertion = isValidIPv4 ip;
        message = "Node '${name}' has an invalid IP address defined: ${ip}.";
      }
    ];

    services.k3s = {
      enable = true;
      inherit role;
      tokenFile = tokenFileFn config;
      # We combine the base flags with the specific flags here to avoid conflicts
      extraFlags = lib.concatStringsSep " " (builtins.filter (s: s != "") [
        (mkDefaultFlags ip)
        extraFlags
      ]);
    };

    systemd.services.k3s = lib.mkIf (clusterInterface != null) {
      after = ["network-online.target" "network-addresses-${clusterInterface}.service"];
      wants = ["network-online.target"];
    };
  };

  # --- Controller Construction ---
  controllerModule = {config, ...}: let
    serverSpecificFlags = lib.concatStringsSep " " (builtins.filter (s: s != "") [
      "--bind-address ${controllerIp}"
      "--advertise-address ${controllerIp}"
      (
        if !controllerIsSchedulable
        then "--disable-agent"
        else ""
      )
      (
        if controllerDisableTraefik
        then "--disable traefik"
        else ""
      )
      controllerExtraFlags
    ]);
  in
    mkBaseModule {
      inherit config;
      name = controllerHostname;
      ip = controllerIp;
      role = "server";
      extraFlags = serverSpecificFlags;
    };

  # --- Agent Construction ---
  mkWorkerModule = name: cfg: {config, ...}:
    mkBaseModule {
      inherit name config;
      ip = cfg.ip;
      role = "agent";
      extraFlags = lib.concatStringsSep " " (builtins.filter (s: s != "") [
        "--server https://${controllerIp}:6443"
        (cfg.extraFlags or "")
      ]);
    };

  workerModules = lib.mapAttrs mkWorkerModule nodes;
in
  if globalCheck
  then workerModules // {"${controllerHostname}" = controllerModule;}
  else throw "K3s Cluster Module: Evaluation failed due to invalid parameters."
