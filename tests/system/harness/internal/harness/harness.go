package harness

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var transportFixturePaths = []string{
	"tests/system/fixture/host.nix",
	"tests/system/fixture/installer.nix",
}

// config parameterizes a single rebuild run.
type Config struct {
	Rev              string
	Host             string
	StateDir         string
	EvidenceDir      string
	CacheDir         string
	TrustedPublicKey string
	PreparedSource   string
	Port             int
	RAM              int
	Cores            int
	Disk             string
	Subcommand       string // check | build-cache | gate | provision | all
	Confirm          ConfirmFunc
}

func CreateRunDir(root, rev, subcommand string, startedAt time.Time) (string, error) {
	absRoot, err := filepath.Abs(root)
	if err != nil {
		return "", fmt.Errorf("resolve evidence root %q: %w", root, err)
	}
	revision := shortRev(rev)
	if revision == "" || filepath.Base(revision) != revision || revision == "." {
		return "", fmt.Errorf("revision %q is not a safe path segment", revision)
	}
	if subcommand == "" || filepath.Base(subcommand) != subcommand || subcommand == "." {
		return "", fmt.Errorf("subcommand %q is not a safe path segment", subcommand)
	}
	revisionDir := filepath.Join(absRoot, revision)
	if err := os.MkdirAll(revisionDir, 0o755); err != nil {
		return "", fmt.Errorf("create evidence revision directory %s: %w", revisionDir, err)
	}
	leaf := startedAt.UTC().Format("20060102T150405Z") + "-" + subcommand
	runDir := filepath.Join(revisionDir, leaf)
	if err := os.Mkdir(runDir, 0o755); err != nil {
		return "", fmt.Errorf("create evidence run directory %s: %w", runDir, err)
	}
	return runDir, nil
}

// confirm func prompts a human and returns the typed response.
type ConfirmFunc func(prompt string) (string, error)

// harness drives the fail-closed rebuild state machine.
type Harness struct {
	cfg                  Config
	runner               Runner
	log                  *log.Logger
	cache                *Cache
	server               *FileServer
	manifest             *Manifest
	signingKey           SigningKey
	repoRoot             string
	preparedSource       string
	preparedSourceHash   string
	preparedSourceStatus string
	sshKey               string
	guest                *Guest
	goldenDir            string
}

// new builds a harness and a nil logger writes to stderr.
func New(cfg Config, runner Runner, logger *log.Logger) *Harness {
	if logger == nil {
		logger = log.New(os.Stderr, "rebuild-vm-golden ", log.LstdFlags)
	}
	return &Harness{
		cfg:    cfg,
		runner: runner,
		log:    logger,
		cache: &Cache{
			Dir:         cfg.CacheDir,
			EvidenceDir: cfg.EvidenceDir,
			Rev:         cfg.Rev,
			Runner:      runner,
		},
		manifest: &Manifest{
			Rev:        cfg.Rev,
			Subcommand: cfg.Subcommand,
			Host:       cfg.Host,
			RunDir:     cfg.EvidenceDir,
			StartedAt:  time.Now().UTC(),
		},
	}
}

type stage struct {
	name        string
	destructive bool
	fn          func(ctx context.Context) error
}

func (h *Harness) allStages() []stage {
	return []stage{
		{name: "preflight", fn: h.stagePreflight},
		{name: "resolve-rev", fn: h.stageResolveRev},
		{name: "prepare-source", fn: h.stagePrepareSource},
		{name: "eval-drv", fn: h.stageEvalDrv},
		{name: "signing-key", fn: h.stageSigningKey},
		{name: "export-sign", fn: h.stageExportSign},
		{name: "cache-check", fn: h.stageCacheCheck},
		{name: "build-plan-gate", fn: h.stageBuildPlanGate},
		{name: "serve-cache", fn: h.stageServeCache},
		{name: "guest-launch", fn: h.stageGuestLaunch},
		{name: "negative-wipe-probe", fn: h.stageNegativeWipeProbe},
		{name: "confirm-gate", destructive: true, fn: h.stageConfirmGate},
		{name: "guest-provision", destructive: true, fn: h.stageGuestProvision},
		{name: "first-boot-proof", fn: h.stageFirstBootProof},
		{name: "freeze", fn: h.stageFreeze},
		{name: "overlay-proof", fn: h.stageOverlayProof},
		{name: "finalize", fn: h.stageFinalize},
	}
}

func (h *Harness) stagesFor(sub string) ([]stage, error) {
	all := h.allStages()
	byName := make(map[string]stage, len(all))
	for _, s := range all {
		byName[s.name] = s
	}
	var names []string
	switch sub {
	case "check":
		names = []string{"preflight", "resolve-rev", "prepare-source", "eval-drv", "cache-check"}
	case "gate":
		names = []string{"preflight", "resolve-rev", "prepare-source", "eval-drv", "cache-check", "build-plan-gate"}
	case "build-cache":
		names = []string{"preflight", "resolve-rev", "prepare-source", "eval-drv", "signing-key", "export-sign", "serve-cache"}
	case "provision":
		names = []string{"preflight", "resolve-rev", "prepare-source", "eval-drv", "signing-key", "export-sign", "cache-check", "build-plan-gate", "serve-cache", "guest-launch", "negative-wipe-probe", "confirm-gate", "guest-provision", "first-boot-proof"}
	case "all":
		for _, s := range all {
			names = append(names, s.name)
		}
	default:
		return nil, fmt.Errorf("unknown subcommand %q (want check|build-cache|gate|provision|all)", sub)
	}
	out := make([]stage, 0, len(names))
	for _, n := range names {
		out = append(out, byName[n])
	}
	return out, nil
}

// run executes the selected stages fail closed while deferred teardown and
// report writing always run.
func (h *Harness) Run(ctx context.Context) (*Manifest, error) {
	defer h.teardown()
	defer h.writeReport()

	stages, err := h.stagesFor(h.cfg.Subcommand)
	if err != nil {
		h.finish("invalid", "dispatch")
		return h.manifest, err
	}

	last := "dispatch"
	for _, st := range stages {
		if cerr := ctx.Err(); cerr != nil {
			h.finish("aborted", last)
			return h.manifest, fmt.Errorf("aborted before stage %s: %w", st.name, cerr)
		}
		if st.destructive {
			h.log.Printf("stage %s: DESTRUCTIVE", st.name)
		}
		start := time.Now()
		h.log.Printf("stage %s: start", st.name)
		serr := st.fn(ctx)
		rec := StageRecord{Name: st.name, Elapsed: time.Since(start)}
		if serr != nil {
			rec.Status = "failed"
			rec.Err = serr.Error()
			h.manifest.Stages = append(h.manifest.Stages, rec)
			h.finish("failed", st.name)
			h.log.Printf("stage %s: FAILED: %v", st.name, serr)
			return h.manifest, fmt.Errorf("stage %s: %w", st.name, serr)
		}
		rec.Status = "pass"
		h.manifest.Stages = append(h.manifest.Stages, rec)
		last = st.name
		h.log.Printf("stage %s: pass (%s)", st.name, rec.Elapsed.Round(time.Millisecond))
	}
	h.finish("complete", last)
	return h.manifest, nil
}

func (h *Harness) finish(status, finalStage string) {
	h.manifest.Status = status
	h.manifest.FinalStage = finalStage
	h.manifest.FinishedAt = time.Now().UTC()
}

func (h *Harness) teardown() {
	if h.guest != nil {
		h.guest.stop()
		h.guest = nil
	}
	if h.server != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = h.server.Close(ctx)
		h.server = nil
	}
}

func (h *Harness) writeReport() {
	dir := h.cfg.EvidenceDir
	if dir == "" {
		return
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		h.log.Printf("write report: %v", err)
		return
	}
	if err := h.manifest.WriteJSON(filepath.Join(dir, "report.json")); err != nil {
		h.log.Printf("write report json: %v", err)
	}
	if err := h.manifest.WriteHuman(filepath.Join(dir, "report.txt")); err != nil {
		h.log.Printf("write report txt: %v", err)
	}
}

func (h *Harness) stagePreflight(ctx context.Context) error {
	_ = ctx
	if strings.TrimSpace(h.cfg.Rev) == "" {
		return fmt.Errorf("rev is required")
	}
	if h.cfg.StateDir == "" {
		return fmt.Errorf("state-dir is required")
	}
	if h.cfg.EvidenceDir == "" {
		return fmt.Errorf("resolved evidence run directory is required")
	}
	for _, d := range []string{h.cfg.StateDir, h.cfg.EvidenceDir, h.cfg.CacheDir} {
		if d == "" {
			continue
		}
		if err := os.MkdirAll(d, 0o755); err != nil {
			return fmt.Errorf("create dir %s: %w", d, err)
		}
	}
	return nil
}

func (h *Harness) stageResolveRev(ctx context.Context) error {
	res := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"rev-parse", "--verify", h.cfg.Rev + "^{commit}"}}, nil)
	if res.Err != nil || res.ExitCode != 0 {
		return fmt.Errorf("resolve rev %q (exit %d): %w\n%s", h.cfg.Rev, res.ExitCode, res.Err, res.Combined)
	}
	if full := strings.TrimSpace(res.Stdout); full != "" {
		h.manifest.Rev = full
		h.manifest.ApprovedRev = full
		h.cache.Rev = full
	}
	top := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"rev-parse", "--show-toplevel"}}, nil)
	if top.Err != nil || top.ExitCode != 0 {
		return fmt.Errorf("resolve repo root (exit %d): %w\n%s", top.ExitCode, top.Err, top.Combined)
	}
	h.repoRoot = strings.TrimSpace(top.Stdout)
	return nil
}

func (h *Harness) stagePrepareSource(ctx context.Context) error {
	if h.repoRoot == "" {
		return fmt.Errorf("resolve-rev must run before prepare-source")
	}
	if h.cfg.PreparedSource != "" {
		return h.stageReusePreparedSource(ctx)
	}
	prepared := filepath.Join(h.cfg.EvidenceDir, "prepared-source")
	if err := os.RemoveAll(prepared); err != nil {
		return fmt.Errorf("reset prepared source %s: %w", prepared, err)
	}
	if err := h.checkoutPreparedRevision(ctx, prepared); err != nil {
		return err
	}
	keyDir := filepath.Join(h.cfg.EvidenceDir, "transport-key")
	if err := os.MkdirAll(keyDir, 0o700); err != nil {
		return fmt.Errorf("create transport key directory: %w", err)
	}
	keyPath := filepath.Join(keyDir, "id_ed25519")
	_ = os.Remove(keyPath)
	_ = os.Remove(keyPath + ".pub")
	generated := h.runner.Run(ctx, CmdSpec{Name: "ssh-keygen", Args: []string{"-q", "-t", "ed25519", "-N", "", "-C", "lexicon-furnish-vm-test", "-f", keyPath}}, nil)
	if generated.Err != nil || generated.ExitCode != 0 {
		return fmt.Errorf("generate VM transport key (exit %d): %w\n%s", generated.ExitCode, generated.Err, generated.Combined)
	}
	pub, err := os.ReadFile(keyPath + ".pub")
	if err != nil {
		return fmt.Errorf("read VM transport public key: %w", err)
	}
	fields := strings.Fields(string(pub))
	if len(fields) < 2 {
		return fmt.Errorf("generated VM transport public key is malformed")
	}
	publicLine := fields[0] + " " + fields[1] + " lexicon-furnish-vm-test"
	const placeholder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElUx+G8NdV6W0NVEh3wpOg33mBnHY0oG9b31eds/LSs furnish-vm-test"
	for _, rel := range transportFixturePaths {
		path := filepath.Join(prepared, rel)
		body, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("read transport-key fixture %s: %w", rel, err)
		}
		if !strings.Contains(string(body), placeholder) {
			return fmt.Errorf("transport-key placeholder is missing from %s", rel)
		}
		updated := strings.ReplaceAll(string(body), placeholder, publicLine)
		if err := os.WriteFile(path, []byte(updated), 0o644); err != nil {
			return fmt.Errorf("write transport-key fixture %s: %w", rel, err)
		}
	}
	status := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"-C", prepared, "status", "--porcelain=v1"}}, nil)
	if status.Err != nil || status.ExitCode != 0 {
		return fmt.Errorf("prepared source status (exit %d): %w\n%s", status.ExitCode, status.Err, status.Combined)
	}
	statusLines := splitNonEmptyLines(status.Stdout)
	sort.Strings(statusLines)
	if err := validateTransportFixtureStatus(statusLines); err != nil {
		return err
	}
	fingerprint, err := preparedSourceFingerprint(prepared, h.manifest.Rev, statusLines)
	if err != nil {
		return err
	}
	h.preparedSource = prepared
	h.preparedSourceStatus = strings.Join(statusLines, "\n")
	h.preparedSourceHash = fingerprint
	h.sshKey = keyPath
	h.manifest.PreparedSourcePath = prepared
	h.manifest.PreparedSourceHash = h.preparedSourceHash
	h.manifest.PreparedSourceStatus = h.preparedSourceStatus
	h.manifest.PreparedSourceReused = boolPtr(false)
	return nil
}

func (h *Harness) stageReusePreparedSource(ctx context.Context) error {
	if h.cfg.Subcommand != "check" && h.cfg.Subcommand != "gate" {
		return fmt.Errorf("--prepared-source is allowed only for check and gate")
	}
	prepared, err := filepath.Abs(h.cfg.PreparedSource)
	if err != nil {
		return fmt.Errorf("resolve prepared source %q: %w", h.cfg.PreparedSource, err)
	}
	if _, err := os.Stat(filepath.Join(prepared, ".git")); err != nil {
		return fmt.Errorf("prepared source %s is not a git worktree: %w", prepared, err)
	}
	head := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"-C", prepared, "rev-parse", "HEAD"}}, nil)
	if head.Err != nil || head.ExitCode != 0 {
		return fmt.Errorf("read reused prepared source HEAD (exit %d): %w\n%s", head.ExitCode, head.Err, head.Combined)
	}
	if got := strings.TrimSpace(head.Stdout); got != h.manifest.Rev {
		return fmt.Errorf("reused prepared source HEAD mismatch: got %q want %q", got, h.manifest.Rev)
	}
	status := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"-C", prepared, "status", "--porcelain=v1"}}, nil)
	if status.Err != nil || status.ExitCode != 0 {
		return fmt.Errorf("reused prepared source status (exit %d): %w\n%s", status.ExitCode, status.Err, status.Combined)
	}
	statusLines := splitNonEmptyLines(status.Stdout)
	sort.Strings(statusLines)
	if err := validateTransportFixtureStatus(statusLines); err != nil {
		return err
	}
	if err := rejectIdentityLeak(prepared); err != nil {
		return err
	}
	fingerprint, err := preparedSourceFingerprint(prepared, h.manifest.Rev, statusLines)
	if err != nil {
		return err
	}
	h.preparedSource = prepared
	h.preparedSourceStatus = strings.Join(statusLines, "\n")
	h.preparedSourceHash = fingerprint
	h.manifest.PreparedSourcePath = prepared
	h.manifest.PreparedSourceStatus = h.preparedSourceStatus
	h.manifest.PreparedSourceHash = h.preparedSourceHash
	h.manifest.PreparedSourceReused = boolPtr(true)
	h.manifest.PreparedSourceOrigin = filepath.Dir(prepared)
	return nil
}

func validateTransportFixtureStatus(statusLines []string) error {
	if len(statusLines) != len(transportFixturePaths) {
		return fmt.Errorf("prepared source must differ only by the transport-key fixtures, got %v", statusLines)
	}
	for i, rel := range transportFixturePaths {
		if !strings.HasSuffix(statusLines[i], rel) {
			return fmt.Errorf("prepared source must differ only by the transport-key fixtures, got %v", statusLines)
		}
	}
	return nil
}

func preparedSourceFingerprint(prepared, rev string, statusLines []string) (string, error) {
	parts := []string{rev}
	for _, rel := range transportFixturePaths {
		sum, err := sha256File(filepath.Join(prepared, rel))
		if err != nil {
			return "", fmt.Errorf("hash transport-key fixture %s: %w", rel, err)
		}
		parts = append(parts, sum)
	}
	parts = append(parts, strings.Join(statusLines, "\n"))
	sum := sha256.Sum256([]byte(strings.Join(parts, "\n")))
	return hex.EncodeToString(sum[:]), nil
}

func (h *Harness) checkoutPreparedRevision(ctx context.Context, prepared string) error {
	if res := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"clone", "--no-local", "--quiet", h.repoRoot, prepared}}, nil); res.Err != nil || res.ExitCode != 0 {
		return fmt.Errorf("clone prepared source (exit %d): %w\n%s", res.ExitCode, res.Err, res.Combined)
	}
	if res := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"-C", prepared, "fetch", "--quiet", "--no-tags", h.repoRoot, h.manifest.Rev}}, nil); res.Err != nil || res.ExitCode != 0 {
		return fmt.Errorf("fetch approved rev into prepared source (exit %d): %w\n%s", res.ExitCode, res.Err, res.Combined)
	}
	if res := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"-C", prepared, "checkout", "--quiet", "--detach", h.manifest.Rev}}, nil); res.Err != nil || res.ExitCode != 0 {
		return fmt.Errorf("checkout approved rev in prepared source (exit %d): %w\n%s", res.ExitCode, res.Err, res.Combined)
	}
	head := h.runner.Run(ctx, CmdSpec{Name: "git", Args: []string{"-C", prepared, "rev-parse", "HEAD"}}, nil)
	if head.Err != nil || head.ExitCode != 0 || strings.TrimSpace(head.Stdout) != h.manifest.Rev {
		return fmt.Errorf("prepared source HEAD mismatch: got %q want %q", strings.TrimSpace(head.Stdout), h.manifest.Rev)
	}
	return nil
}

func (h *Harness) stageEvalDrv(ctx context.Context) error {
	if h.preparedSource == "" {
		return fmt.Errorf("prepared source is empty; prepare-source must run first")
	}
	if h.manifest.DrvPaths == nil {
		h.manifest.DrvPaths = map[string]string{}
	}
	evalDrv := func(name, attr string) (string, error) {
		res := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: []string{"eval", "--raw", h.flakeRef(attr)}}, nil)
		if res.Err != nil || res.ExitCode != 0 {
			return "", fmt.Errorf("eval %s drvPath (exit %d): %w\n%s", name, res.ExitCode, res.Err, res.Combined)
		}
		drv, err := singleStorePath(res.Stdout, ".drv")
		if err != nil {
			return "", fmt.Errorf("eval %s drvPath: %w\nstdout: %q\ncombined:\n%s", name, err, res.Stdout, res.Combined)
		}
		return drv, nil
	}
	toplevel, err := evalDrv("toplevel", fmt.Sprintf("nixosConfigurations.%s.config.system.build.toplevel.drvPath", h.cfg.Host))
	if err != nil {
		return err
	}
	disko, err := evalDrv("disko", fmt.Sprintf("nixosConfigurations.%s.config.system.build.destroyFormatMount.drvPath", h.cfg.Host))
	if err != nil {
		return err
	}
	h.manifest.DrvPaths["toplevel"] = toplevel
	h.manifest.DrvPaths["disko"] = disko
	return nil
}

func (h *Harness) recordDrvComparison(name, expected, observed string) error {
	proof := Proof{
		Name:     name,
		Expected: strings.TrimSpace(expected),
		Observed: strings.TrimSpace(observed),
		Match:    SameDrv(expected, observed),
	}
	h.manifest.DrvComparisons = append(h.manifest.DrvComparisons, proof)
	if !proof.Match {
		return fmt.Errorf("%s drvPath mismatch: expected %q observed %q", name, proof.Expected, proof.Observed)
	}
	return nil
}

func (h *Harness) stageCacheCheck(ctx context.Context) error {
	_ = ctx
	h.manifest.CacheKey = h.cache.CacheKey()
	h.manifest.CacheDir = h.cfg.CacheDir
	inv, err := h.cache.Inventory()
	if err != nil {
		return err
	}
	h.manifest.CacheNarinfoCount = intPtr(len(inv))
	if len(inv) == 0 {
		return fmt.Errorf("cache %s is empty; run build-cache first", h.cfg.CacheDir)
	}
	return nil
}

func (h *Harness) stageBuildPlanGate(ctx context.Context) error {
	if err := h.stageStaticBuildPlanGate(ctx); err != nil {
		return err
	}
	return h.stageSubstitutionCompletenessGate(ctx)
}

func (h *Harness) stageStaticBuildPlanGate(ctx context.Context) error {
	if h.manifest.StorePaths == nil {
		h.manifest.StorePaths = map[string]string{}
	}
	store := "file://" + h.cfg.CacheDir
	trusted := h.cache.KeyName()
	for _, name := range []string{"toplevel", "disko"} {
		drv := h.manifest.DrvPaths[name]
		if drv == "" {
			return fmt.Errorf("no %s drv resolved; eval-drv must run first", name)
		}
		show := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: []string{"derivation", "show", drv}}, nil)
		if show.Err != nil || show.ExitCode != 0 {
			return fmt.Errorf("derivation show %s (exit %d): %w\n%s", drv, show.ExitCode, show.Err, show.Combined)
		}
		outPath, err := drvOutPath(show.Stdout, drv)
		if err != nil {
			return fmt.Errorf("resolve %s out path: %w\nstdout: %q\ncombined:\n%s", name, err, show.Stdout, show.Combined)
		}
		pi := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: []string{"path-info", "--store", store, "--recursive", "--sigs", "--json", outPath}}, nil)
		if pi.Err != nil || pi.ExitCode != 0 {
			return fmt.Errorf("gate not cached: %s closure of %s incomplete in signed cache %s (exit %d): %w\n%s", name, outPath, store, pi.ExitCode, pi.Err, pi.Combined)
		}
		closure, err := parsePathInfoSigs(pi.Stdout)
		if err != nil {
			return fmt.Errorf("parse %s cache closure: %w\nstdout: %q", name, err, pi.Stdout)
		}
		if len(closure) == 0 {
			return fmt.Errorf("gate vacuous: signed cache %s returned an empty closure for %s", store, outPath)
		}
		if _, ok := closure[outPath]; !ok {
			return fmt.Errorf("gate not cached: %s out %s absent from its own cached closure", name, outPath)
		}
		for p, sigs := range closure {
			if !signedByKey(sigs, trusted) {
				return fmt.Errorf("gate not cached: %s is not signed by trusted key %s", p, trusted)
			}
		}
		h.manifest.StorePaths[name] = outPath
	}
	return nil
}

func (h *Harness) stageSubstitutionCompletenessGate(ctx context.Context) error {
	trustedPublicKey := strings.TrimSpace(h.manifest.PublicKey)
	if trustedPublicKey == "" {
		trustedPublicKey = strings.TrimSpace(h.cfg.TrustedPublicKey)
	}
	keyName, _, ok := NormalizePubKey(trustedPublicKey)
	if !ok || keyName != h.cache.KeyName() {
		return fmt.Errorf("trusted public key must be supplied for %s", h.cache.KeyName())
	}
	roots, err := h.gateStorePaths()
	if err != nil {
		return err
	}
	storeRoot := filepath.Join(h.cfg.EvidenceDir, "realization-store")
	if err := prepareFreshStoreRoot(storeRoot); err != nil {
		return err
	}
	before, err := h.inventoryIsolatedStore(ctx, storeRoot, "pre-copy realization")
	if err != nil {
		return err
	}
	h.manifest.RealizationBeforePaths = intPtr(len(before))
	if len(before) != 0 {
		return fmt.Errorf("fresh realization store inventory is not empty: %d path(s)", len(before))
	}

	var violation string
	copied := h.copySignedClosure(ctx, storeRoot, trustedPublicKey, roots, buildGateWatcher(func(v string) { violation = v }))
	if errors.Is(copied.Err, ErrEmergencyStop) {
		return fmt.Errorf("%w: build announced during substitution completeness copy: %s", ErrEmergencyStop, violation)
	}
	if copied.Err != nil || copied.ExitCode != 0 {
		return fmt.Errorf("substitution completeness copy failed (exit %d): %w\n%s", copied.ExitCode, copied.Err, copied.Combined)
	}
	copyCount := ScanBuildPlan(copied.Combined).FetchCount()
	h.manifest.GateFetchCount = intPtr(copyCount)
	if copyCount == 0 {
		return fmt.Errorf("substitution completeness copy fetched zero paths from the signed cache")
	}

	buildArgs := []string{
		"build", "--no-link",
		"--store", "local?root=" + storeRoot,
		"--option", "substituters", "file://" + h.cfg.CacheDir,
		"--option", "trusted-public-keys", trustedPublicKey,
		"--option", "require-sigs", "true",
		"--option", "always-allow-substitutes", "true",
		"--option", "max-jobs", "0",
		"--option", "builders", "",
	}
	buildArgs = append(buildArgs, roots...)
	built := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: buildArgs}, buildGateWatcher(func(v string) { violation = v }))
	plan := ScanBuildPlan(built.Combined)
	if errors.Is(built.Err, ErrEmergencyStop) {
		// the watcher stops on the first announcement before the complete plan is
		// observable, so the truncated scan must not publish a zero measurement.
		h.manifest.GateBuildCount = nil
		return fmt.Errorf("%w: build announced during substitution completeness realization: %s", ErrEmergencyStop, violation)
	}
	if built.Err != nil || built.ExitCode != 0 {
		return fmt.Errorf("substitution completeness realization failed (exit %d): %w\n%s", built.ExitCode, built.Err, built.Combined)
	}
	h.manifest.GateBuildCount = intPtr(plan.BuildCount())
	if !plan.IsClean() {
		return fmt.Errorf("substitution completeness realization would build %d derivation(s): %s", plan.BuildCount(), strings.Join(plan.WillBuild, ", "))
	}
	for _, root := range roots {
		if err := h.requireIsolatedPath(ctx, storeRoot, root); err != nil {
			return err
		}
	}
	paths, err := h.inventoryIsolatedStore(ctx, storeRoot, "realization")
	if err != nil {
		return err
	}
	if len(paths) == 0 {
		return fmt.Errorf("realization store inventory is empty after successful copy")
	}
	if len(paths) != copyCount {
		return fmt.Errorf("realization store count mismatch: copied=%d inventory=%d", copyCount, len(paths))
	}
	h.manifest.RealizationAfterPaths = intPtr(len(paths))
	if err := removeIsolatedStoreRoot(storeRoot); err != nil {
		return fmt.Errorf("discard successful realization store %s: %w", storeRoot, err)
	}
	return nil
}

func prepareFreshStoreRoot(storeRoot string) error {
	if err := os.Mkdir(storeRoot, 0o755); err != nil {
		return fmt.Errorf("create fresh isolated store root %s: %w", storeRoot, err)
	}
	entries, err := os.ReadDir(storeRoot)
	if err != nil {
		return fmt.Errorf("inspect fresh isolated store root %s: %w", storeRoot, err)
	}
	if len(entries) != 0 {
		return fmt.Errorf("isolated store root %s is not empty", storeRoot)
	}
	return nil
}

func removeIsolatedStoreRoot(storeRoot string) error {
	if err := filepath.Walk(storeRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return os.Chmod(path, info.Mode().Perm()|0o200)
		}
		return nil
	}); err != nil {
		return fmt.Errorf("make isolated store removable: %w", err)
	}
	return os.RemoveAll(storeRoot)
}

func (h *Harness) gateStorePaths() ([]string, error) {
	var roots []string
	for _, name := range []string{"toplevel", "disko"} {
		path := h.manifest.StorePaths[name]
		if path == "" {
			return nil, fmt.Errorf("%s out path is empty; static gate must run first", name)
		}
		roots = append(roots, path)
	}
	return roots, nil
}

func (h *Harness) copySignedClosure(ctx context.Context, storeRoot, trustedPublicKey string, roots []string, watch LineWatcher) CmdResult {
	args := []string{
		"copy",
		"--from", "file://" + h.cfg.CacheDir,
		"--to", "local?root=" + storeRoot,
		"--option", "trusted-public-keys", trustedPublicKey,
		"--option", "require-sigs", "true",
	}
	args = append(args, roots...)
	return h.runner.Run(ctx, CmdSpec{Name: "nix", Args: args}, watch)
}

func (h *Harness) requireIsolatedPath(ctx context.Context, storeRoot, outPath string) error {
	present := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: []string{"path-info", "--store", "local?root=" + storeRoot, outPath}}, nil)
	if present.Err != nil || present.ExitCode != 0 {
		return fmt.Errorf("isolated store is missing required out path %s (exit %d): %w\n%s", outPath, present.ExitCode, present.Err, present.Combined)
	}
	return nil
}

func (h *Harness) inventoryIsolatedStore(ctx context.Context, storeRoot, label string) ([]string, error) {
	inventory := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: []string{"path-info", "--store", "local?root=" + storeRoot, "--all", "--json"}}, nil)
	if inventory.Err != nil || inventory.ExitCode != 0 {
		return nil, fmt.Errorf("inventory %s store (exit %d): %w\n%s", label, inventory.ExitCode, inventory.Err, inventory.Combined)
	}
	paths, err := parsePathInfoPaths(inventory.Stdout)
	if err != nil {
		return nil, fmt.Errorf("parse %s store inventory: %w", label, err)
	}
	return paths, nil
}

func (h *Harness) stageSigningKey(ctx context.Context) error {
	_ = ctx
	key, err := GenerateSigningKey(h.cfg.EvidenceDir, h.cache.KeyName())
	if err != nil {
		return err
	}
	h.signingKey = key
	h.manifest.PublicKey = key.Public
	return nil
}

func (h *Harness) stageExportSign(ctx context.Context) error {
	if err := h.cache.Ensure(); err != nil {
		return err
	}
	if h.manifest.StorePaths == nil {
		h.manifest.StorePaths = map[string]string{}
	}
	var roots []string
	for _, name := range []string{"toplevel", "disko"} {
		drv := h.manifest.DrvPaths[name]
		if drv == "" {
			return fmt.Errorf("no %s drv resolved; eval-drv must run first", name)
		}
		res := h.runner.Run(ctx, CmdSpec{Name: "nix", Args: []string{"build", "--no-link", "--print-out-paths", drv + "^*"}}, nil)
		if res.Err != nil || res.ExitCode != 0 {
			return fmt.Errorf("realize %s (exit %d): %w\n%s", name, res.ExitCode, res.Err, res.Combined)
		}
		outPath, err := singleStorePath(res.Stdout, "")
		if err != nil {
			return fmt.Errorf("realize %s output: %w\nstdout: %q\ncombined:\n%s", name, err, res.Stdout, res.Combined)
		}
		h.manifest.StorePaths[name] = outPath
		roots = append(roots, outPath)
	}
	closure, err := h.cache.ClosurePaths(ctx, roots)
	if err != nil {
		return err
	}
	total := len(closure)
	started := time.Now()
	logCacheProgress(h.log, "copied", 0, total, started)
	if err := h.cache.Sign(ctx, h.signingKey, roots); err != nil {
		return err
	}
	if err := h.cache.Export(ctx, roots); err != nil {
		return err
	}
	logCacheProgress(h.log, "copied", total, total, started)
	logCacheProgress(h.log, "signed", 0, total, started)
	if err := h.cache.SignStore(ctx, h.signingKey, roots); err != nil {
		return err
	}
	verified, err := h.cache.VerifyCurrentRunKey(ctx, h.signingKey, roots)
	if err != nil {
		return err
	}
	logCacheProgress(h.log, "signed", verified, total, started)
	h.manifest.CacheDir = h.cfg.CacheDir
	inventory, err := h.cache.Inventory()
	if err != nil {
		return err
	}
	h.manifest.CacheNarinfoCount = intPtr(len(inventory))
	return nil
}

func (h *Harness) stageServeCache(ctx context.Context) error {
	_ = ctx
	if err := h.cache.Ensure(); err != nil {
		return err
	}
	srv, err := StartFileServer(h.cfg.CacheDir, h.cfg.Port)
	if err != nil {
		return err
	}
	h.server = srv
	h.log.Printf("serving cache %s at %s", h.cfg.CacheDir, srv.URL())
	return nil
}

func (h *Harness) stageConfirmGate(ctx context.Context) error {
	_ = ctx
	if h.cfg.Confirm == nil {
		return fmt.Errorf("destructive stage requires a confirmation function")
	}
	short := shortRev(h.manifest.Rev)
	prompt := fmt.Sprintf("About to WIPE and reinstall host %q at rev %s.\nProbed destructive target: /dev/vda (negative-wipe probe passed).\nType the rev short-hash %q to proceed: ", h.cfg.Host, h.manifest.Rev, short)
	got, err := h.cfg.Confirm(prompt)
	if err != nil {
		return fmt.Errorf("confirmation aborted: %w", err)
	}
	if strings.TrimSpace(got) != short {
		return fmt.Errorf("confirmation mismatch: got %q want %q", strings.TrimSpace(got), short)
	}
	return nil
}

func (h *Harness) stageFinalize(ctx context.Context) error {
	_ = ctx
	if h.goldenDir != "" {
		h.manifest.GoldenDir = h.goldenDir
	}
	h.log.Printf("run complete for rev %s (golden: %s)", h.manifest.Rev, h.manifest.GoldenDir)
	return nil
}

func (h *Harness) flakeRef(attr string) string {
	if h.preparedSource != "" {
		return fmt.Sprintf("git+file://%s#%s", h.preparedSource, attr)
	}
	return fmt.Sprintf("git+file://%s?rev=%s#%s", h.repoRoot, h.manifest.Rev, attr)
}

func buildGateWatcher(onViolation func(string)) LineWatcher {
	return func(line string) error {
		if v := BuildLineViolation(line); v != "" {
			if onViolation != nil {
				onViolation(v)
			}
			return fmt.Errorf("%w: %s", ErrEmergencyStop, v)
		}
		return nil
	}
}

var reDiskNode = regexp.MustCompile(`/dev/(?:vd[a-z]|sd[a-z]|xvd[a-z]|nvme\d+n\d+)\b`)

func scanDiskoDevices(output string) []string {
	seen := map[string]bool{}
	var out []string
	for _, m := range reDiskNode.FindAllString(output, -1) {
		if seen[m] {
			continue
		}
		seen[m] = true
		out = append(out, m)
	}
	return out
}

func splitNonEmptyLines(s string) []string {
	var out []string
	for _, ln := range strings.Split(s, "\n") {
		if ln = strings.TrimSpace(ln); ln != "" {
			out = append(out, ln)
		}
	}
	return out
}

var reStorePath = regexp.MustCompile(`^/nix/store/\S+$`)

func singleStorePath(s, suffix string) (string, error) {
	lines := splitNonEmptyLines(s)
	if len(lines) != 1 {
		return "", fmt.Errorf("want exactly one /nix/store path, got %d line(s)", len(lines))
	}
	p := lines[0]
	if !reStorePath.MatchString(p) {
		return "", fmt.Errorf("not a /nix/store path: %q", p)
	}
	if suffix != "" && !strings.HasSuffix(p, suffix) {
		return "", fmt.Errorf("store path %q does not end in %q", p, suffix)
	}
	return p, nil
}

func storePathLines(s string) []string {
	var out []string
	for _, ln := range splitNonEmptyLines(s) {
		if reStorePath.MatchString(ln) {
			out = append(out, ln)
		}
	}
	return out
}

func drvOutPath(jsonStr, drv string) (string, error) {
	var m map[string]struct {
		Outputs map[string]struct {
			Path string `json:"path"`
		} `json:"outputs"`
	}
	if err := json.Unmarshal([]byte(strings.TrimSpace(jsonStr)), &m); err != nil {
		return "", fmt.Errorf("unmarshal derivation show json: %w", err)
	}
	entry, ok := m[drv]
	if !ok && len(m) == 1 {
		for _, v := range m {
			entry, ok = v, true
		}
	}
	if !ok {
		return "", fmt.Errorf("derivation %s absent from `nix derivation show` output", drv)
	}
	out, ok := entry.Outputs["out"]
	if !ok {
		return "", fmt.Errorf("derivation %s has no \"out\" output", drv)
	}
	return singleStorePath(out.Path, "")
}

func parsePathInfoSigs(jsonStr string) (map[string][]string, error) {
	s := strings.TrimSpace(jsonStr)
	out := map[string][]string{}
	if s == "" {
		return out, nil
	}
	switch s[0] {
	case '[':
		var arr []struct {
			Path       string   `json:"path"`
			Signatures []string `json:"signatures"`
		}
		if err := json.Unmarshal([]byte(s), &arr); err != nil {
			return nil, fmt.Errorf("unmarshal path-info array: %w", err)
		}
		for _, e := range arr {
			if strings.TrimSpace(e.Path) == "" {
				continue
			}
			out[e.Path] = e.Signatures
		}
	case '{':
		var obj map[string]*struct {
			Signatures []string `json:"signatures"`
		}
		if err := json.Unmarshal([]byte(s), &obj); err != nil {
			return nil, fmt.Errorf("unmarshal path-info object: %w", err)
		}
		for p, e := range obj {
			if e == nil {
				return nil, fmt.Errorf("path-info: %s not present in the signed cache", p)
			}
			out[p] = e.Signatures
		}
	default:
		return nil, fmt.Errorf("unexpected path-info json (leading %q)", s[0])
	}
	return out, nil
}

func signedByKey(sigs []string, keyName string) bool {
	for _, sig := range sigs {
		if name, _, ok := NormalizePubKey(sig); ok && name == keyName {
			return true
		}
	}
	return false
}

func rejectIdentityLeak(root string) error {
	return filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		switch info.Name() {
		case "ssh_host_ed25519_key", "ssh_host_ed25519_key.pub":
			return fmt.Errorf("private or public vm identity leaked into prepared source: %s", path)
		}
		return nil
	})
}
