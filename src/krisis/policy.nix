# a policy is { handlers, initial, result } and swapping it is the only way
# to change what a reported diagnostic does
{
  lib,
  emit,
  severities,
}:
let
  halted = {
    __krisisHalted = true;
  };

  wasHalted = value: builtins.isAttrs value && value ? __krisisHalted;

  isError = diagnostic: diagnostic.severity == "error";

  summarize = diagnostics: {
    inherit diagnostics;
    total = builtins.length diagnostics;
    hasErrors = builtins.any isError diagnostics;
  };

  outcome =
    { value, state }:
    summarize state
    // {
      halted = wasHalted value;
      value = if wasHalted value then null else value;
    };

  append =
    { param, state }:
    {
      resume = null;
      state = state ++ [ param ];
    };

  render =
    long: diagnostic:
    let
      location = lib.optionalString (diagnostic.at != null) " at ${diagnostic.at}";
      head = "${diagnostic.severity}: ${diagnostic.code}${location}: ${diagnostic.message}";
      tail = lib.optionals long (
        map (note: "  note: ${note}") diagnostic.notes
        ++ lib.optional (diagnostic.help != null) "  help: ${diagnostic.help}"
      );
    in
    [ head ] ++ tail |> lib.concatStringsSep "\n";
in
rec {
  inherit halted wasHalted;

  collect = {
    handlers.${emit.reportEffect} = append;
    initial = [ ];
    result = outcome;
  };

  # the first error discards the continuation, so nothing downstream of a
  # broken value gets evaluated
  stopFirst = {
    handlers.${emit.reportEffect} =
      { param, state }:
      if isError param then
        {
          abort = halted;
          state = state ++ [ param ];
        }
      else
        append { inherit param state; };
    initial = [ ];
    result = outcome;
  };

  # state holds codes and severities and no messages, so the trampoline's
  # deepSeq of handler state never forces a rendered value
  count = {
    handlers.${emit.reportEffect} =
      { param, state }:
      {
        resume = null;
        state = {
          total = state.total + 1;
          bySeverity = state.bySeverity // {
            ${param.severity} = state.bySeverity.${param.severity} + 1;
          };
          byCode = state.byCode // {
            ${param.code} = (state.byCode.${param.code} or 0) + 1;
          };
        };
      };
    initial = {
      total = 0;
      bySeverity = lib.genAttrs severities (_: 0);
      byCode = { };
    };
    result =
      { value, state }:
      state
      // {
        halted = wasHalted value;
        hasErrors = state.bySeverity.error > 0;
        value = if wasHalted value then null else value;
      };
  };

  pretty =
    {
      long ? false,
    }:
    {
      handlers.${emit.reportEffect} =
        { param, state }:
        {
          resume = null;
          state = {
            lines = state.lines ++ [ (render long param) ];
            errors = state.errors + (if isError param then 1 else 0);
          };
        };
      initial = {
        lines = [ ];
        errors = 0;
      };
      result =
        { value, state }:
        {
          report = lib.concatStringsSep "\n" state.lines;
          inherit (state) lines;
          total = builtins.length state.lines;
          hasErrors = state.errors > 0;
          halted = wasHalted value;
          value = if wasHalted value then null else value;
        };
    };

  # same handlers as collect, named for the read-only use
  inspect = collect;
}
