{ lib }:
{
  getNamed = hostName: modulesSets:
    lib.concatMap (
      modSet:
        if modSet ? ${hostName}
        then
          (
            if builtins.isList modSet.${hostName}
            then modSet.${hostName}
            else [modSet.${hostName}]
          )
        else []
    )
    modulesSets;
}
