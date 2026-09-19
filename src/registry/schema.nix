# declaration shapes only. these schemas decide whether a declaration is
# well-formed, never what it means; the dimension space, the den layer, and
# every cross-record rule live in core.nix.
#
# optional fields a later layer may supply default to null rather than to their
# final value, so core can tell "the author said this" apart from "nobody said
# anything" when the lexicon and den layers are merged.
{
  lib,
  axiom,
  krisis,
  fields,
}:
let
  inherit (axiom) validation;
  inherit (fields)
    absolute
    closed
    diagnostic
    field
    finish
    nameList
    nonEmpty
    nullable
    problem
    qualifiedPart
    required
    stringAttrs
    ;

  dimensionSchema =
    name:
    let
      subject = "dimensions.${name}";
    in
    closed "dimension" subject {
      values =
        required subject "dimension-values" "values must be a list of unique, non-empty strings"
          nameList;
      required = field subject "dimension-required" "required must be a boolean" builtins.isBool // {
        default = false;
      };
      default =
        field subject "dimension-default" "default must be a non-empty string or null" (nullable nonEmpty)
        // {
          default = null;
        };
    };

  namedResult =
    kind: subject: name: parsed:
    let
      diagnostics = validation.collect [
        (validation.optional (!qualifiedPart name) (
          diagnostic subject "${kind}-name" "${kind} names must be non-empty and cannot contain '/'"
        ))
        parsed.diagnostics
      ];
    in
    validation.fromDiagnostics diagnostics (
      (parsed.value or { })
      // {
        inherit name;
      }
    );

  dimensionResult =
    name: raw: namedResult "dimension" "dimensions.${name}" name (dimensionSchema name raw);

  parseDimensions =
    value:
    if !builtins.isAttrs value then
      validation.failure [
        (diagnostic "dimensions" "dimensions-shape" "dimensions must be an attribute set")
      ]
    else
      validation.traverseAttrs dimensionResult value;

  homeSchema =
    subject:
    closed "host home" subject {
      home = required subject "user-on-home" "home must be an absolute path string" absolute;
    };

  parseOn =
    subject: value:
    if !builtins.isAttrs value then
      validation.failure [
        (diagnostic subject "user-on-shape" "on must be an attribute set keyed by host name")
      ]
    else
      validation.traverseAttrs (
        host: raw:
        let
          parsed = homeSchema "${subject}.on.${host}" raw;
        in
        validation.fromDiagnostics parsed.diagnostics (parsed.value or { })
      ) value;

  # the three fields a user may carry wherever that user is declared
  identityFields = subject: {
    id = field subject "user-id" "id must be a non-empty string" (nullable nonEmpty) // {
      default = null;
    };
    aliases =
      field subject "user-aliases" "aliases must be a list of unique, non-empty strings" (
        nullable nameList
      )
      // {
        default = null;
      };
    home = field subject "user-home" "home must be an absolute path string" (nullable absolute) // {
      default = null;
    };
  };

  userSchema =
    subject:
    closed "user" subject (
      identityFields subject
      // {
        hosts =
          field subject "user-hosts" "hosts must be a list of unique, non-empty host names" (
            nullable nameList
          )
          // {
            default = null;
          };
        on = {
          default = { };
          parse = parseOn subject;
        };
      }
    );

  hostUserSchema = subject: closed "host user" subject (identityFields subject);

  userResult =
    name: raw:
    let
      subject = "users.${name}";
    in
    namedResult "user" subject name (userSchema subject raw);

  parseUsers =
    value:
    if !builtins.isAttrs value then
      validation.failure [ (diagnostic "users" "users-shape" "users must be an attribute set") ]
    else
      validation.traverseAttrs userResult value;

  parseHostUsers =
    subject: value:
    if !builtins.isAttrs value then
      validation.failure [
        (diagnostic subject "host-users-shape" "a host's users must be an attribute set")
      ]
    else
      validation.traverseAttrs (
        name: raw:
        namedResult "user" "${subject}.users.${name}" name (hostUserSchema "${subject}.users.${name}" raw)
      ) value;

  hostSchema =
    subject:
    closed "host" subject {
      system =
        field subject "host-system" "system must be a non-empty name without '/'" (nullable qualifiedPart)
        // {
          default = null;
        };
      aliases =
        field subject "host-aliases" "aliases must be a list of unique, non-empty strings" (
          nullable nameList
        )
        // {
          default = null;
        };
      dimensions =
        field subject "host-dimensions" "dimensions must be an attribute set of strings" stringAttrs
        // {
          default = { };
        };
      users = {
        default = { };
        parse = parseHostUsers subject;
      };
    };

  # a null host is an explicit exclusion and carries no shape of its own
  hostResult =
    name: raw:
    let
      subject = "hosts.${name}";
    in
    if raw == null then
      validation.fromDiagnostics (validation.optional (!qualifiedPart name) (
        diagnostic subject "host-name" "host names must be non-empty and cannot contain '/'"
      )) null
    else
      namedResult "host" subject name (hostSchema subject raw);

  parseHosts =
    value:
    if !builtins.isAttrs value then
      validation.failure [ (diagnostic "hosts" "hosts-shape" "hosts must be an attribute set") ]
    else
      validation.traverseAttrs hostResult value;

  # den stays unvalidated and unforced here. it is an opaque input the den layer
  # reads later, and forcing it at declaration time would defeat the laziness the
  # den adapter exists to preserve.
  declarationSchema = closed "declaration" "registry" {
    den = {
      default = null;
    };
    root = field "root" "root" "root must be a Nix path" builtins.isPath // {
      default = null;
    };
    runtimeRoot =
      field "runtimeRoot" "runtime-root" "runtimeRoot must be an absolute path string or null" (
        nullable absolute
      )
      // {
        default = null;
      };
    defaultSystem =
      field "defaultSystem" "default-system" "defaultSystem must be a non-empty name without '/' or null"
        (nullable qualifiedPart)
      // {
        default = null;
      };
    dimensions = {
      default = { };
      parse = parseDimensions;
    };
    hosts = {
      default = { };
      parse = parseHosts;
    };
    users = {
      default = { };
      parse = parseUsers;
    };
  };

  # the four required keys are checked by presence rather than by the schema's
  # own required flag, so each one can say what to write when the answer is
  # genuinely nothing
  missingField =
    raw: key: help:
    validation.optional (builtins.isAttrs raw && !(raw ? ${key})) (problem {
      code = "${key}-missing";
      message = "${key} is required";
      primary.label = key;
      inherit help;
    });

  declarationResult =
    raw:
    let
      parsed = declarationSchema raw;
      diagnostics = validation.collect [
        (missingField raw "root" "root is the Nix path holding this configuration's source")
        (missingField raw "runtimeRoot" "set runtimeRoot = null when there is no live checkout")
        (missingField raw "hosts" "declare hosts = { } when this fleet registers no hosts")
        (missingField raw "users" "declare users = { } when this fleet registers no users")
        parsed.diagnostics
      ];
    in
    validation.fromDiagnostics diagnostics (parsed.value or { });

  contextSchema = closed "context" "context" {
    host = required "context.host" "context-host" "host must be a non-empty name" nonEmpty;
    user =
      field "context.user" "context-user" "user must be a non-empty name, id, alias, or null" (
        nullable nonEmpty
      )
      // {
        default = null;
      };
  };
in
{
  declaration = raw: finish (declarationResult raw);
  context = raw: finish (contextSchema raw);
}
