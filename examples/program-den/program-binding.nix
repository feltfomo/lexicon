{ lexicon, den }:
# one constructor call is the whole Den binding; the roster, selected principal,
# and host-user inventory come from den's public value
lexicon.lib.programDen { inherit den; }
