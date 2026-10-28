# a locked flake reference for a resolved side. getFlake only takes a url, and a
# narHash can hold characters a query string would misread
{
  source,
  narHash,
  ...
}:
"path:${source}?narHash=${
  builtins.replaceStrings
    [
      "+"
      "/"
      "="
    ]
    [
      "%2B"
      "%2F"
      "%3D"
    ]
    narHash
}"
