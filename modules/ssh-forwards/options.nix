{
  lib,
  sensible_option,
  ...
}:
with lib; let
  portForwardOpts = {
    options = {
      localPort = mkOption {
        type = types.port;
        default = 22;
        description = "Port bound on the virtual WireGuard IP on the relay host.";
      };
      remoteHost = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Target address relative to the remote SSH endpoint.";
      };
      remotePort = mkOption {
        type = types.port;
        default = 22;
        description = "Destination port on the remote host.";
      };
    };
  };

  tunnelOpts = {name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };

      targetHost = mkOption {
        type = types.str;
        description = "External SSH hostname or IP to connect to from the relay.";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SSH username on the remote host (falls back to defaultUser).";
      };

      bindIp = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Virtual IPv4 bound on the relay host. Automatically resolved from sensible.wireguard.<interface>.topology.nodes.<name> if null.";
      };

      identityFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Private key path used both by the relay tunnel and fleet SSH clients (falls back to defaultIdentityFile).";
      };

      proxyJump = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional jump host specification or name of another tunnel in sensible.ssh-forwards.tunnels.";
      };

      strictHostKeyChecking = mkOption {
        type = types.nullOr (types.enum [
          "yes"
          "no"
          "accept-new"
          "off"
        ]);
        default = null;
      };

      forwards = mkOption {
        type = types.listOf (types.submodule portForwardOpts);
        default = [
          {
            localPort = 22;
            remoteHost = "127.0.0.1";
            remotePort = 22;
          }
        ];
        description = "List of local port forwards bound to bindIp on the relay host.";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional raw CLI arguments appended to the relay ssh invocation.";
      };

      clientExtraOptions = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional SSH client options injected into Home Manager matchBlocks on fleet clients.";
      };
    };
  };
in
  sensible_option {
    ssh-forwards = mkOption {
      default = {};
      description = "Declarative WireGuard-backed SSH bastion port-forwards with unified client SSH integration.";
      type = types.submodule {
        options = {
          enable = mkEnableOption "Sensible SSH bastion port-forwards";

          relayHost = mkOption {
            type = types.str;
            default = "";
            description = "Hostname of the relay node that binds the virtual IPs and maintains the outbound SSH tunnels.";
          };

          wireguardInterface = mkOption {
            type = types.nullOr types.str;
            default = "wg0";
            description = "WireGuard interface on relayHost where virtual IPs are attached and from which node IPs are derived.";
          };

          serviceUser = mkOption {
            type = types.str;
            default = "root";
            description = "Local system user on relayHost running the persistent SSH tunnel daemons.";
          };

          defaultUser = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default remote SSH user for tunnels.";
          };

          defaultIdentityFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default SSH private key path used by both the relay tunnels and client matchBlocks.";
          };

          defaultStrictHostKeyChecking = mkOption {
            type = types.nullOr (types.enum [
              "yes"
              "no"
              "accept-new"
              "off"
            ]);
            default = "accept-new";
          };

          manageRelaySshdListenAddresses = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically restrict sshd on relayHost to its own node IP and relayListenAddresses so port 22 forwards do not collide with 0.0.0.0:22.";
          };

          relayListenAddresses = mkOption {
            type = types.listOf types.str;
            default = [
              "127.0.0.1"
            ];
            description = "Additional IPv4 addresses sshd on relayHost should listen on when manageRelaySshdListenAddresses is enabled.";
          };

          generateWrapperScripts = mkOption {
            type = types.bool;
            default = true;
            description = "Generate 'ssh-<tunnel>' convenience wrapper scripts on all hosts.";
          };

          serverAliveInterval = mkOption {
            type = types.ints.positive;
            default = 30;
          };

          serverAliveCountMax = mkOption {
            type = types.ints.positive;
            default = 3;
          };

          tunnels = mkOption {
            type = types.attrsOf (types.submodule tunnelOpts);
            default = {};
            description = "Declarative SSH port-forward tunnels keyed by alias name.";
          };
        };
      };
    };
  }
