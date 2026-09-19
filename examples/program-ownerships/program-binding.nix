{ lexicon, roster }:
# this constructor adds selection only where the application needs claims
lexicon.lib.programOwnerships { inherit roster; }
