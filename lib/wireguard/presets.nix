{lib}: rec {
  mkCallable = baseAttrs:
    baseAttrs
    // {
      __functor = self: overrides:
        mkCallable (lib.recursiveUpdate (builtins.removeAttrs self ["__functor"]) overrides);
    };

  mkForward = port: targetNode: let
    mkFwd = state:
      state
      // {
        __functor = self: opts: let
          clean = builtins.removeAttrs self ["__functor"];
          updated =
            if builtins.isInt opts
            then clean // {targetPort = opts;}
            else if builtins.isString opts
            then clean // {protocol = opts;}
            else clean // opts;
        in
          mkFwd updated;
      };
  in
    mkFwd {
      inherit port targetNode;
      targetPort = null;
      targetNetwork = null;
      protocol = "tcp";
    };

  mkForwardUDP = port: targetNode: (mkForward port targetNode) "udp";

  # Preset 1: Alla noder i nätverket litar på varandra och kan kommunicera fritt (mesh/spoke-relay)
  mkMesh = mkCallable {
    mode = "mesh";
    isolated = false;
    firewall = {
      trustInterface = true;
      allowPeerToPeer = true;
      allowPing = true;
    };
  };

  # Preset 2: Som mesh, men hubben agerar även brygga/NAT ut mot ett fysiskt gränssnitt (t.ex. "eth0")
  mkGateway = interface:
    mkCallable {
      mode = "gateway";
      inherit interface;
      isolated = false;
      firewall = {
        trustInterface = true;
        allowPeerToPeer = true;
        allowExternalRouting = true;
        allowPing = true;
      };
    };

  # Preset 3: Klienter kan nå hubben, men är isolerade från att prata direkt med varandra
  mkHubOnly = mkCallable {
    mode = "hub-only";
    isolated = false;
    firewall = {
      trustInterface = false;
      allowPeerToPeer = false;
      allowExternalRouting = false;
      allowPing = true;
    };
  };

  # Preset 4: Strikt zero-trust-nätverk där endast explicit öppnade portar och forwards tillåts
  mkIsolated = mkCallable {
    mode = "isolated";
    isolated = true;
    firewall = {
      trustInterface = false;
      allowPeerToPeer = false;
      allowExternalRouting = false;
      allowPing = false;
    };
  };

  # Exponerar en specifik tjänst över ett isolerat nätverk
  exposeService = port: targetNode:
    mkIsolated {
      forwards = [(mkForward port targetNode)];
    };
}
