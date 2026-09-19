{
  label = "mobile autosave";
  # the fallback keeps inspection contexts without mobile well-defined
  when = { host, ... }: host.mobile or false;
  editor.autosaveSeconds = 30;
}
