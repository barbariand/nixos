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

  # Preset 1: Full mesh där noder litar på varandra; mappar hosts som standard
  mkMesh = mkCallable {
    mode = "mesh";
    isolated = false;
    hosts = {
      enable = true;
      domain = null;
    };
    firewall = {
      trustInterface = true;
      allowPeerToPeer = true;
      allowPing = true;
    };
  };

  # Preset 2: Mesh med gateway NAT
  mkGateway = interface:
    mkCallable {
      mode = "gateway";
      inherit interface;
      isolated = false;
      hosts = {
        enable = true;
        domain = null;
      };
      firewall = {
        trustInterface = true;
        allowPeerToPeer = true;
        allowExternalRouting = true;
        allowPing = true;
      };
    };

  # Preset 3: Hub-only
  mkHubOnly = mkCallable {
    mode = "hub-only";
    isolated = false;
    hosts = {
      enable = false;
      domain = null;
    };
    firewall = {
      trustInterface = false;
      allowPeerToPeer = false;
      allowExternalRouting = false;
      allowPing = true;
    };
  };

  # Preset 4: Strikt isolerat nätverk (t.ex. wg1 för externa vänner)
  mkIsolated = mkCallable {
    mode = "isolated";
    isolated = true;
    hosts = {
      enable = false;
      domain = null;
    };
    firewall = {
      trustInterface = false;
      allowPeerToPeer = false;
      allowExternalRouting = false;
      allowPing = false;
    };
  };

  exposeService = port: targetNode:
    mkIsolated {
      forwards = [(mkForward port targetNode)];
    };
}
