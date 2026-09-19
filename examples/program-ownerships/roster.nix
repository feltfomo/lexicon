{ ownerships, system }:
ownerships.toRoster [
  (ownerships.define.host "studio" { inherit system; })
  (ownerships.define.user "alice" { hosts = [ "studio" ]; })
  (ownerships.define.user "bob" { hosts = [ "studio" ]; })
]
