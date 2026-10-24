{
  fx,
  native,
  axiom,
}:
let
  inherit (fx.state) mkThunk forceThunk;
  toDiagnostic =
    diagnostic:
    if builtins.isString diagnostic then
      {
        code = "lexicon/legacy";
        severity = "error";
        message = diagnostic;
        context = mkThunk diagnostic;
      }
    else
      {
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
      previous: diagnostic:
      fx.bind previous (
        _:
        let
          normalized = toDiagnostic diagnostic;
          # envelope demand must preserve callback exceptions before validation
        in
        builtins.seq normalized.code (builtins.seq normalized.severity (native.report.emit normalized))
      )
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
  accept =
    value:
    fx.pure {
      _con = "Valid";
      value = mkThunk value;
    };
  fromDiagnostics =
    diagnostics: value:
    if diagnostics == [ ] then
      accept value
    else
      fx.bind (emitAll diagnostics) (_: fx.pure { _con = "Invalid"; });
  run = result: interpret (fromAxiom result);
  eliminate =
    fail: succeed: report:
    let
      diagnostics = map (diagnostic: forceThunk diagnostic.context) report.diagnostics;
    in
    if report.diagnostics != [ ] then
      fail diagnostics
    else if report.outcome._con == "Success" then
      let
        checked = forceThunk report.outcome.value;
      in
      if checked._con == "Valid" then
        succeed (forceThunk checked.value)
      else if checked._con == "Invalid" then
        throw "lexicon: invalid validation without diagnostics"
      else
        throw "lexicon: unknown checked constructor"
    else if report.outcome._con == "Failure" then
      throw "lexicon: failed validation without diagnostics"
    else
      throw "lexicon: unknown outcome constructor";
  finishComputation = fail: computation: eliminate fail (value: value) (interpret computation);
  # static checked validations emit diagnostics without aborting
  share =
    computation:
    let
      report = interpret computation;
      checked =
        if report.outcome._con == "Failure" then
          { _con = "Invalid"; }
        else if report.outcome._con == "Success" then
          let
            value = forceThunk report.outcome.value;
          in
          if value._con == "Valid" || value._con == "Invalid" then
            value
          else
            throw "lexicon: unknown checked constructor"
        else
          throw "lexicon: unknown outcome constructor";
      emissions = builtins.foldl' (
        previous: diagnostic: fx.bind previous (_: native.report.emit diagnostic)
      ) (fx.pure null) report.diagnostics;
    in
    fx.bind emissions (_: fx.pure checked);
  resultOf = computation: resultFromReport (interpret computation);
  resultFromReport = eliminate axiom.validation.failure axiom.validation.success;
  finishReport = fail: eliminate fail (value: value);
  finish = fail: result: finishComputation fail (fromAxiom result);
in
{
  inherit
    fx
    native
    fromAxiom
    run
    finish
    toDiagnostic
    accept
    fromDiagnostics
    interpret
    resultOf
    resultFromReport
    finishReport
    finishComputation
    share
    ;
}
