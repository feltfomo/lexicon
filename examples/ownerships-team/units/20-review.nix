{
  hosts = [
    "workstation"
    "laptop"
  ];
  users = [
    "alice"
    "robin"
  ];
  tools = [ "typos" ];
  review.language = "en";
  # the child can only narrow the reviewer and host claims above
  children = [
    {
      label = "review on a small screen";
      hosts = [ "laptop" ];
      editor.wrap = true;
    }
  ];
}
