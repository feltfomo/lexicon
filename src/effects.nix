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
  checkedFromReport =
    report:
    let
      inherit (report) outcome;
      failure = message: if report.diagnostics == [ ] then throw message else { _con = "Invalid"; };
    in
    if outcome._con == "Failure" then
      if builtins.attrNames outcome != [ "_con" ] then
        throw "lexicon: impossible failure constructor"
      else
        failure "lexicon: failed validation without diagnostics"
    else if outcome._con == "Success" then
      let
        checked = forceThunk outcome.value;
      in
      if
        builtins.attrNames outcome != [
          "_con"
          "value"
        ]
      then
        throw "lexicon: impossible success constructor"
      else if checked._con == "Invalid" then
        if builtins.attrNames checked != [ "_con" ] then
          throw "lexicon: impossible invalid constructor"
        else
          failure "lexicon: invalid validation without diagnostics"
      else if checked._con == "Valid" then
        if
          builtins.attrNames checked != [
            "_con"
            "value"
          ]
        then
          throw "lexicon: impossible valid constructor"
        else
          checked
      else
        throw "lexicon: unknown checked constructor"
    else
      throw "lexicon: unknown outcome constructor";
  eliminateWith =
    project: fail: succeed: report:
    let
      checked = checkedFromReport report;
    in
    if builtins.seq checked (report.diagnostics != [ ]) then
      let
        diagnostics = project report.diagnostics;
      in
      builtins.seq diagnostics (fail diagnostics)
    else
      succeed (forceThunk checked.value);
  eliminate = eliminateWith (map (diagnostic: forceThunk diagnostic.context));
  # settle each mapped envelope before the next callback without demanding presentation
  mappedResultFromReport =
    mapper:
    eliminateWith (
      diagnostics:
      let
        mapped = map (
          diagnostic:
          let
            retained = mapper diagnostic;
            normalized = toDiagnostic retained;
          in
          builtins.seq normalized.code (
            builtins.seq normalized.severity (builtins.seq (native.diagnostic.make normalized) retained)
          )
        ) diagnostics;
        settled = builtins.foldl' (unit: diagnostic: builtins.seq diagnostic unit) null mapped;
      in
      builtins.seq settled mapped
    ) axiom.validation.failure axiom.validation.success;
  finishComputation = fail: computation: eliminate fail (value: value) (interpret computation);
  # static checked validations emit diagnostics without aborting
  share =
    computation:
    let
      report = interpret computation;
      checked = checkedFromReport report;
      emissions = builtins.foldl' (
        previous: diagnostic: fx.bind previous (_: native.report.emit diagnostic)
      ) (fx.pure null) report.diagnostics;
    in
    builtins.seq checked (fx.bind emissions (_: fx.pure checked));
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
    mappedResultFromReport
    finishReport
    finishComputation
    share
    ;
}
