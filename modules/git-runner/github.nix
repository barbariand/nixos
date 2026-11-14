{
  cfg,
  activeGithubRunners,
  hostPackages,
  sharedEnv,
  lib,
}:
with lib; let
  gCfg = cfg.github;
  stripForgejoSuffix = label: removeSuffix ":host" label;

  resolveLabels = rCfg: let
    raw =
      if rCfg.labels != null
      then rCfg.labels
      else if gCfg.labels != null
      then gCfg.labels
      else cfg.labels;
  in
    map stripForgejoSuffix raw;

  mkGithubRunner = _id: rCfg: let
    effectiveTokenFile =
      if rCfg.tokenFile != null
      then rCfg.tokenFile
      else gCfg.tokenFile;

    effectiveEphemeral =
      if rCfg.ephemeral != null
      then rCfg.ephemeral
      else gCfg.ephemeral;

    effectiveReplace =
      if rCfg.replace != null
      then rCfg.replace
      else gCfg.replace;

    effectiveRunnerGroup =
      if rCfg.runnerGroup != null
      then rCfg.runnerGroup
      else gCfg.runnerGroup;

    baseService =
      {
        enable = true;
        url = rCfg.url;
        name = rCfg.name;
        tokenFile = effectiveTokenFile;
        ephemeral = effectiveEphemeral;
        replace = effectiveReplace;
        extraLabels = resolveLabels rCfg;
        extraPackages = hostPackages;
        extraEnvironment = sharedEnv;
        user = "git-runner";
        group = "git-runner";
        serviceOverrides =
          {
            DynamicUser = mkForce false;
            CPUWeight = cfg.priority.cpuWeight;
            IOWeight = cfg.priority.ioWeight;
            MemoryHigh = "10G";
            MemoryMax = "12G";
            OOMScoreAdjust = cfg.priority.oomScoreAdjust;
          }
          // optionalAttrs (cfg.envFile != null) {
            EnvironmentFile = cfg.envFile;
          };
      }
      // optionalAttrs (effectiveRunnerGroup != null) {
        runnerGroup = effectiveRunnerGroup;
      };
  in
    recursiveUpdate (recursiveUpdate baseService gCfg.extraSettings) rCfg.extraSettings;
in {
  services.github-runners = mkIf (activeGithubRunners != {}) (
    mapAttrs mkGithubRunner activeGithubRunners
  );
}
