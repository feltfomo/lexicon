[
  {
    hosts = [
      "workstation"
      "laptop"
    ];
    tools = [ "git" ];
    # children can only narrow the parent match
    children = [
      {
        users = [ "alice" ];
        tools = [ "helix" ];
        children = [
          {
            exceptHosts = [ "workstation" ];
            editor.wrap = true;
          }
        ];
      }
      {
        exceptUsers = [ "alice" ];
        tools = [ "vim" ];
      }
    ];
  }
  {
    # the predicate stays defined when mobile is absent from the context
    when = { host, ... }: host.mobile or false;
    lowPower = true;
  }
]
