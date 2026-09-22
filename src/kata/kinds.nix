# data. a kind says what it is called, where its declaration lands, whether the
# layer above already holds its schema, and which kind it lands inside. which
# blocks it may carry is read off the block
_: [
  {
    name = "entry";
    collection = "entries";
    parent = null;
    container = null;
    # the whole spec is blocks, so there is no declare to unwrap
    declare = false;
    fields = t: [
      {
        name = "blocks";
        type = t.Attrs;
        default = { };
      }
    ];
  }
  {
    name = "home";
    collection = "homes";
    parent = null;
    container = null;
    declare = false;
    fields = t: [
      {
        name = "blocks";
        type = t.Attrs;
        default = { };
      }
    ];
  }
  {
    name = "user";
    collection = "users";
    # a user reaches a declaration inside the host that includes it, under the
    # key that host holds its users in. the layer below reads the same pair
    parent = "host";
    container = "users";
    # a null fields is how this registry says the schema is already held
    # elsewhere
    declare = true;
    fields = null;
  }
  {
    name = "host";
    collection = "hosts";
    parent = null;
    container = null;
    declare = true;
    fields = null;
  }
]
