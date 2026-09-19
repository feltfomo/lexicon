# a subsystem only says what is wrong. whether that ends the build is the
# caller's call
{ fx }:
let
  reportEffect = "krisis/report";
  haltEffect = "krisis/halt";

  report = diagnostic: fx.send reportEffect diagnostic;
  reportAll = diagnostics: fx.seq (map report diagnostics);

  # diagnostics from inside are replayed outward before the halt, so the
  # caller's policy still sees them in the order they were reported
  gate =
    comp:
    fx.bind
      (fx.effects.scope.runWith {
        handlers = {
          ${reportEffect} =
            { param, state }:
            {
              resume = null;
              state = state ++ [ param ];
            };
        };
        state = [ ];
      } comp)
      (
        inner:
        fx.bind (reportAll inner.state) (
          _:
          if builtins.any (diagnostic: diagnostic.severity == "error") inner.state then
            fx.send haltEffect null
          else
            fx.pure inner.value
        )
      );
in
{
  inherit
    reportEffect
    haltEffect
    report
    reportAll
    gate
    ;
}
