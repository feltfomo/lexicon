{ ownerships }:
ownerships.toRoster [
  # system-qualified host ids keep inspection contexts unambiguous
  (ownerships.define.host "workstation" { system = "x86_64-linux"; })
  (ownerships.define.host "laptop" { system = "x86_64-linux"; })
  (ownerships.define.user "alice" {
    hosts = [
      "workstation"
      "laptop"
    ];
  })
  (ownerships.define.user "sam" { hosts = [ "workstation" ]; })
  (ownerships.define.user "robin" { hosts = [ "laptop" ]; })
]
