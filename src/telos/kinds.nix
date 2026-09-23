# data. a kind says where an output declaration is written. a host writes the
# outputs that belong to its own system, and the fleet writes the ones that
# belong to no host. which blocks each carries is read off the block
#
# these kinds hold no fields of their own. an output declaration carries
# nothing but its blocks, and the system an output lands under is read from
# the host that declared it rather than written again here
#
# a sourced kind names what it was written for before it writes anything, so
# a file declaring outputs for a host says which host by name
_: [
  {
    name = "host";
    collection = "hosts";
    parent = null;
    container = null;
    declare = false;
    fields = null;
    sourced = true;
  }
  {
    name = "fleet";
    collection = "fleet";
    parent = null;
    container = null;
    declare = false;
    fields = null;
    sourced = false;
  }
]
