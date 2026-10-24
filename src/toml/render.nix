encoded:
let
  inherit (builtins)
    all
    attrNames
    concatLists
    concatStringsSep
    elemAt
    filter
    genList
    length
    map
    ;
  del = builtins.fromJSON ''"\u007f"'';
  quote = value: builtins.replaceStrings [ del ] [ "\\u007f" ] (builtins.toJSON value);
  pure = fragments: {
    inherit fragments;
    literals = [ ];
  };
  combine = parts: {
    fragments = concatLists (map (part: part.fragments) parts);
    literals = concatLists (map (part: part.literals) parts);
  };
  indexed = f: values: genList (index: f index (elemAt values index)) (length values);
  delimited = open: separator: close: parts: {
    fragments = [
      open
    ]
    ++ concatLists (
      indexed (index: part: (if index == 0 then [ ] else [ separator ]) ++ part.fragments) parts
    )
    ++ [ close ];
    literals = concatLists (map (part: part.literals) parts);
  };
  float = value: if builtins.match ".*[.eE].*" value != null then value else value + ".0";
  dotted = path: concatStringsSep "." (map quote path);
  tablesOf = node: if node.kind == "tables" then node.value.value else node.value;
  isSection =
    node:
    node.kind == "table"
    || node.kind == "tables" && node.value.value != [ ]
    || node.kind == "array" && node.value != [ ] && all (item: item.kind == "table") node.value;
  inlineTable =
    path: attrs:
    let
      fields = map (
        key:
        let
          rendered = valueAt (path ++ [ key ]) attrs.${key};
        in
        rendered
        // {
          fragments = [
            (quote key)
            " = "
          ]
          ++ rendered.fragments;
        }
      ) (attrNames attrs);
    in
    if fields == [ ] then pure [ "{}" ] else delimited "{\n" ",\n" "\n}" fields;
  array =
    path: values:
    let
      parts = indexed (index: valueAt (path ++ [ index ])) values;
    in
    if parts == [ ] then pure [ "[]" ] else delimited "[\n" ",\n" "\n]" parts;
  values = {
    scalar =
      _: value: pure [ (if builtins.isFloat value then float (builtins.toJSON value) else quote value) ];
    float = _: value: pure [ (float value) ];
    literal = path: value: {
      # a following separator must start after any trailing literal comment
      fragments = [
        value
        "\n"
      ];
      literals = [
        {
          inherit path;
          text = value;
        }
      ];
    };
    table = inlineTable;
    inline = path: value: inlineTable path value.value;
    inherit array;
    tables = path: value: array path value.value;
    document = _: _: throw "toml: document is only valid as the whole input";
  };
  valueAt =
    path: node:
    (values.${node.kind} or (_: _: throw "toml: unknown encoded value kind")) path node.value;
  body =
    prefix: path: attrs:
    let
      entries = map (
        key:
        let
          node = attrs.${key};
          childPath = path ++ [ key ];
          childPrefix = prefix ++ [ key ];
          section = isSection node;
          result =
            if node.kind == "table" then
              combine [
                (pure [
                  "["
                  (dotted childPrefix)
                  "]\n"
                ])
                (body childPrefix childPath node.value)
              ]
            else if section then
              combine (
                indexed (
                  index: table:
                  combine [
                    (pure [
                      "[["
                      (dotted childPrefix)
                      "]]\n"
                    ])
                    (body childPrefix (childPath ++ [ index ]) table.value)
                  ]
                ) (tablesOf node)
              )
            else
              combine [
                (pure [
                  (quote key)
                  " = "
                ])
                (valueAt childPath node)
                (pure [ "\n" ])
              ];
        in
        {
          inherit section result;
        }
      ) (attrNames attrs);
      ordered = filter (entry: !entry.section) entries ++ filter (entry: entry.section) entries;
    in
    {
      fragments = concatLists (map (entry: entry.result.fragments) ordered);
      literals = concatLists (map (entry: entry.result.literals) entries);
    };
  rendered =
    if encoded.kind == "document" then
      pure [ encoded.value ]
    else if encoded.kind == "table" then
      body [ ] [ ] encoded.value
    else
      throw "toml: document must be attributes or a document constructor";
in
{
  text = concatStringsSep "" rendered.fragments;
  inherit (rendered) literals;
}
