{
  fx,
  native,
  axiom,
}:
let
  inherit (fx.state) mkThunk forceThunk;
  toDiagnostic = diagnostic: {
    inherit (diagnostic) code severity message;
    primary =
      let
        location = diagnostic.primary or null;
      in
      if builtins.isAttrs location && builtins.attrNames location == [ ] then null else location;
    related = map (label: {
      location = removeAttrs label [ "message" ];
      message = label.message or null;
    }) (diagnostic.secondaryLabels or [ ]);
    notes = diagnostic.notes or [ ];
    help = diagnostic.help or null;
    context = mkThunk diagnostic;
  };
  emitAll =
    diagnostics:
    builtins.foldl' (
      previous: diagnostic: fx.bind previous (_: native.report.emit (toDiagnostic diagnostic))
    ) (fx.pure null) diagnostics;
  fromAxiom =
    result:
    let
      accepted = axiom.validation.isSuccess result;
    in
    builtins.seq accepted (
      fx.bind (emitAll result.diagnostics) (
        _:
        fx.pure (
          if accepted then
            {
              _con = "Valid";
              value = mkThunk result.value;
            }
          else
            { _con = "Invalid"; }
        )
      )
    );
  collecting = native.report.handlers.collecting { };
  interpret = fx.handle collecting;
  run = result: interpret (fromAxiom result);
  finish =
    fail: result:
    let
      report = run result;
    in
    if report.diagnostics != [ ] then
      fail (map (diagnostic: forceThunk diagnostic.context) report.diagnostics)
    else if report.outcome._con == "Success" then
      let
        checked = forceThunk report.outcome.value;
      in
      if checked._con == "Valid" then
        forceThunk checked.value
      else
        throw "lexicon: invalid validation without diagnostics"
    else
      throw "lexicon: failed validation without diagnostics";
in
{
  inherit
    fx
    native
    fromAxiom
    run
    finish
    toDiagnostic
    ;
}
