package harness

import "testing"

func TestSameDrvIgnoresOuterWhitespace(t *testing.T) {
	want := "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-furnish-vm.drv"
	if !SameDrv("  "+want+"\n", want) {
		t.Fatal("equivalent drv paths did not compare equal")
	}
}

func TestSingleStorePath(t *testing.T) {
	want := "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-furnish-vm.drv"
	got, err := singleStorePath("\n"+want+"\n", ".drv")
	if err != nil || got != want {
		t.Fatalf("singleStorePath() = %q, %v; want %q", got, err, want)
	}
	if _, err := singleStorePath(want+"\n"+want, ".drv"); err == nil {
		t.Fatal("multiple store paths were accepted")
	}
}

func TestDiskoScriptPath(t *testing.T) {
	want := "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-disko-format-mount"
	got, err := diskoScriptPath("warning: fixture\n" + want + "\n")
	if err != nil || got != want {
		t.Fatalf("diskoScriptPath() = %q, %v; want %q", got, err, want)
	}
}

func TestParseUnitState(t *testing.T) {
	got, err := parseUnitState("active\n")
	if err != nil || got != "active" {
		t.Fatalf("parseUnitState() = %q, %v", got, err)
	}
	if _, err := parseUnitState("active\nfailed\n"); err == nil {
		t.Fatal("multiline unit state was accepted")
	}
}

func TestValidatePoweroffOutcome(t *testing.T) {
	if err := validatePoweroffOutcome(255, true, 0, nil); err != nil {
		t.Fatalf("expected clean SSH disconnect and QEMU exit: %v", err)
	}
	if err := validatePoweroffOutcome(1, true, 0, nil); err == nil {
		t.Fatal("unexpected SSH exit was accepted")
	}
}
