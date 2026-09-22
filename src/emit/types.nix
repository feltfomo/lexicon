# the shape of what emission carries
{
  fx,
  t,
}:
let
  Name = t.refined "Name" t.String (value: value != "");

  Capability = t.refined "Capability" t.Any builtins.isFunction;

  # the names one backend may advertise are the names that run answers for,
  # so this type is written against the set in hand
  ContextName = supplyable: t.refined "ContextName" Name (value: builtins.elem value supplyable);

  Target = t.bless (
    fx.types.Record {
      host = t.Attrs;
      modules = t.listOf t.Any;
      carried = t.Attrs;
      built = t.Any;
    }
  );
in
{
  inherit
    Name
    Capability
    ContextName
    Target
    ;
}
