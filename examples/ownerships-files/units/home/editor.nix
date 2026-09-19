{ editor }:
# importUnitSets supplies editor through args
{
  users = [ "alice" ];
  home.sessionVariables.EDITOR = editor;
}
