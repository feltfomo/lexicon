# every reporter method the terminal fixture's cells call, in order. a cell
# that recovers calls exactly the method its failure needs, and a valid cell
# calls none
let
  recovered = sequence: { inherit sequence; };
  failed = sequence: {
    fails = true;
    inherit sequence;
  };
in
{
  prefix = "terminal";
  cells = {
    "dispatch.validShape" = recovered [ ];
    "dispatch.validShapeSentinel" = recovered [ ];
    "dispatch.executorRecovery" = recovered [ "fail" ];
    "dispatch.indexRecovery" = recovered [ "fail" ];
    "dispatch.indexShapeRecovery" = recovered [ "fail" ];
    "dispatch.shapeRecovery" = recovered [ "fail" ];
    "dispatch.compileShapeRecovery" = recovered [
      "provider"
      "fail"
    ];
    "dispatch.capabilityRecovery" = recovered [ "failOne" ];
    "dispatch.materializerRecovery" = recovered [ "failOne" ];
    "dispatch.artifactRecovery" = recovered [ "fail" ];
    "dispatch.externalRecovery" = recovered [ "failOne" ];
    "groups.themeWithin" = recovered [ "checked" ];
    "groups.matugenWithin" = recovered [ "finish" ];
    "groups.themeRecovery" = recovered [
      "checked"
      "checked"
    ];
    "groups.themeSuccessThenRecovery" = recovered [ "checked" ];
    "groups.themeSuccess" = recovered [ ];
    "groups.matugenRecovery" = recovered [
      "finish"
      "finish"
    ];
    "groups.matugenSuccess" = recovered [
      "finish"
      "finish"
    ];
    "groups.matugenNativeOpaque" = recovered [
      "finish"
      "finish"
    ];
    "exceptions.themeWithin" = failed [ ];
    "exceptions.matugenWithin" = failed [ "finish" ];
    "exceptions.themeTwo" = failed [ ];
    "exceptions.themePoison" = failed [ ];
    "exceptions.themeSuccessThenFailure" = failed [ ];
    "exceptions.matugenTwo" = failed [ "finish" ];
    "exceptions.matugenPoison" = failed [ "finish" ];
    "exceptions.matugenSuccessThenFailure" = failed [
      "finish"
      "finish"
    ];
    "exceptions.matugenNativeAfterDuplicate" = failed [ "finish" ];
    "exceptions.themeSuccessPoison" = failed [ ];
  };
}
