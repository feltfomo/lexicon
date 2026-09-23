# one good declaration and two malformed ones for each output block. what the
# suite watches is that a block answers for its own interior under its own
# codes, so a mistake in one block is never reported in another's name
{
  krisis,
  telos,
}:
let
  inherit (telos) blocks;
  inherit (telos.internal) within;

  # the place is installed the way the assembly installs it, so a code lands
  # where the person wrote it rather than at the block's own root
  read =
    name: value:
    krisis.run { policy = krisis.policy.collect; } (
      within
        [
          "fleet"
          name
        ]
        (
          blocks.byName.${name}.validate {
            emit = blocks.emitters.${name};
            inherit value;
          }
        )
    );

  codesOf = name: value: map (diagnostic: diagnostic.code) (read name value).diagnostics;

  placesOf = name: value: map (diagnostic: diagnostic.at) (read name value).diagnostics;

  describe = name: value: blocks.byName.${name}.compile.independent value;

  goodCheck = {
    sealed = {
      steps = [
        {
          name = "seal";
          run = "mkdir -p $out";
        }
      ];
    };
  };

  goodShell = {
    default = {
      packages = [ "jq" ];
    };
  };

  goodPackage = {
    greeting = {
      steps = [
        {
          name = "write";
          run = "mkdir -p $out";
        }
      ];
    };
  };

  goodFormatter = {
    tree = {
      program = "nixfmt";
    };
  };
in
{
  testAGoodCheckIsQuietAndDescribesItsSteps = {
    expr = {
      codes = codesOf "checks" goodCheck;
      described = describe "checks" goodCheck;
    };
    expected = {
      codes = [ ];
      described = {
        sealed = {
          steps = goodCheck.sealed.steps;
        };
      };
    };
  };

  testAChecksBlockThatIsNotAnAttrsetIsRefused = {
    expr = codesOf "checks" [ ];
    expected = [ "telos/checks-interior" ];
  };

  testACheckWithoutStepsIsRefusedAtItsOwnName = {
    expr = {
      codes = codesOf "checks" { sealed = { }; };
      places = placesOf "checks" { sealed = { }; };
    };
    expected = {
      codes = [ "telos/checks-steps-missing" ];
      places = [ "$.fleet.checks.sealed" ];
    };
  };

  testACheckStepMissingItsRunIsRefused = {
    expr = codesOf "checks" {
      sealed = {
        steps = [ { name = "seal"; } ];
      };
    };
    expected = [ "telos/checks-step-malformed" ];
  };

  testAGoodShellIsQuietAndDescribesItsNames = {
    expr = {
      codes = codesOf "devShells" goodShell;
      described = describe "devShells" goodShell;
    };
    expected = {
      codes = [ ];
      described = {
        default = {
          packages = [ "jq" ];
        };
      };
    };
  };

  testADevShellsBlockThatIsNotAnAttrsetIsRefused = {
    expr = codesOf "devShells" "jq";
    expected = [ "telos/devshells-interior" ];
  };

  testAShellDeclaringNoPackageListIsRefused = {
    expr = codesOf "devShells" { default = { }; };
    expected = [ "telos/devshells-packages-malformed" ];
  };

  # a name that is not in the package set cannot be caught here, because the
  # set is handed to the assembly, so what a shell can be held to is whether
  # it named anything at all
  testAShellPackageThatIsNotANameIsRefused = {
    expr = codesOf "devShells" {
      default = {
        packages = [ "" ];
      };
    };
    expected = [ "telos/devshells-package-unnamed" ];
  };

  testAGoodPackageIsQuietAndDescribesItsSteps = {
    expr = {
      codes = codesOf "packages" goodPackage;
      described = describe "packages" goodPackage;
    };
    expected = {
      codes = [ ];
      described = {
        greeting = {
          steps = goodPackage.greeting.steps;
        };
      };
    };
  };

  testAPackagesBlockThatIsNotAnAttrsetIsRefused = {
    expr = codesOf "packages" null;
    expected = [ "telos/packages-interior" ];
  };

  # the two step shaped blocks report under separate names for the same
  # mistake, which is what keeps a package's refusal out of a check's report
  testAPackageStepMissingItsNameIsRefusedUnderItsOwnCode = {
    expr = codesOf "packages" {
      greeting = {
        steps = [ { run = "mkdir -p $out"; } ];
      };
    };
    expected = [ "telos/packages-step-malformed" ];
  };

  testAGoodFormatterIsQuietAndDescribesItsProgram = {
    expr = {
      codes = codesOf "fmt" goodFormatter;
      described = describe "fmt" goodFormatter;
    };
    expected = {
      codes = [ ];
      described = {
        tree = {
          program = "nixfmt";
        };
      };
    };
  };

  testAnFmtBlockThatIsNotAnAttrsetIsRefused = {
    expr = codesOf "fmt" "nixfmt";
    expected = [ "telos/fmt-interior" ];
  };

  # whether the name is in the package set is the assembly's question, so
  # what a formatter is held to here is whether it named a program at all
  testAFormatterNamingNoProgramIsRefusedAtItsOwnName = {
    expr = {
      codes = codesOf "fmt" { tree = { }; };
      places = placesOf "fmt" { tree = { }; };
    };
    expected = {
      codes = [ "telos/fmt-program-unnamed" ];
      places = [ "$.fleet.fmt.tree" ];
    };
  };

  testAFormatterWhoseProgramIsEmptyIsRefused = {
    expr = codesOf "fmt" {
      tree = {
        program = "";
      };
    };
    expected = [ "telos/fmt-program-unnamed" ];
  };
}
