{
  config,
  lib,
  sensibleLib,
  ...
}:
with lib; let
  cfg = config.sensible.k3s;
  wgCfg = config.sensible.wireguard;
  hostName = config.networking.hostName;

  isController = hostName == cfg.controllerNode;
  isWorker = builtins.hasAttr hostName cfg.nodes;
  isParticipant = isController || isWorker;

  resolveNodeIp = name: explicitIp:
    if explicitIp != null
    then explicitIp
    else if cfg.wireguardInterface != null && builtins.hasAttr cfg.wireguardInterface wgCfg && builtins.hasAttr name wgCfg.${cfg.wireguardInterface}.topology.nodes
    then wgCfg.${cfg.wireguardInterface}.topology.nodes.${name}.ip
    else null;

  effectiveControllerIp = resolveNodeIp cfg.controllerNode cfg.controllerIp;
  localIp =
    if isController
    then effectiveControllerIp
    else if isWorker
    then resolveNodeIp hostName cfg.nodes.${hostName}.ip
    else null;

  baseFlags = [
    "--node-ip ${toString localIp}"
    "--node-external-ip ${toString localIp}"
    (optionalString (cfg.wireguardInterface != null) "--flannel-iface ${cfg.wireguardInterface}")
    cfg.globalExtraFlags
  ];

  roleFlags =
    if isController
    then [
      "--bind-address ${toString effectiveControllerIp}"
      "--advertise-address ${toString effectiveControllerIp}"
      (optionalString (!cfg.controllerIsSchedulable) "--disable-agent")
      (optionalString cfg.controllerDisableTraefik "--disable traefik")
      cfg.controllerExtraFlags
    ]
    else [
      cfg.nodes.${hostName}.extraFlags
    ];
in
  {
    condition = cfg.enable && isParticipant;

    assertions = [
      {
        assertion = effectiveControllerIp != null;
        message = "sensible.k3s: Could not resolve controller IP for '${cfg.controllerNode}'.";
      }
      {
        assertion = localIp != null;
        message = "sensible.k3s: Could not resolve local node IP for '${hostName}'.";
      }
    ];

    system = {
      services.k3s =
        {
          enable = true;
          role = if isController then "server" else "agent";
          tokenFile = cfg.tokenFile;
          extraFlags = concatStringsSep " " (filter (s: s != "") (baseFlags ++ roleFlags));
        }
        // optionalAttrs isWorker {
          serverAddr = "https://${effectiveControllerIp}:6443";
        };

      systemd.services.k3s = mkIf (cfg.wireguardInterface != null) {
        after = ["network-online.target" "systemd-networkd.service"];
        wants = ["network-online.target"];
      };
    };
  }
  |> sensibleLib.sensibleConfig
