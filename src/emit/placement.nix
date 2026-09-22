# data. where each registered block's compiled half goes. a classed block
# compiles to modules an evaluator reads. a carried block compiles to data
# whose reader is an external flake this tree cannot read
{ classed, carried }:
{
  nixos = classed "nixos";
  homeManager = classed "homeManager";
  furnish = carried;
  theme = carried;
}
