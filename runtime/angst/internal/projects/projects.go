package projects

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"text/tabwriter"
	"time"

	"angst/internal/cmd"
	"angst/internal/paths"
	"angst/internal/scope"
)

const (
	exitUsage = 2
	exitError = 1
	exitOK    = 0
)

var errStale = errors.New("stale env")

func home() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	hd, _ := os.UserHomeDir()
	return hd
}

func storeRoot() string {
	if v := os.Getenv("ANGST_PROJECTS_STORE"); v != "" {
		return v
	}
	if v := os.Getenv("ANGST_PROJECTS_STORE_DEFAULT"); v != "" {
		return v
	}
	return filepath.Join(home(), ".secrets", "projects")
}

func repoRoot() string {
	if v := os.Getenv("ANGST_PROJECTS_REPO"); v != "" {
		return v
	}
	return filepath.Join(paths.RepoRoot(), "projects")
}

func projectsRoot() string {
	if v := os.Getenv("ANGST_PROJECTS_ROOT"); v != "" {
		return v
	}
	return filepath.Join(home(), "projects")
}

func sidecarDir() string {
	return filepath.Join(home(), ".secrets", "projects")
}

func keys(path string) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	seen := map[string]bool{}
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		eq := strings.IndexByte(line, '=')
		if eq <= 0 {
			continue
		}
		k := line[:eq]
		if !isKeyName(k) {
			continue
		}
		if !seen[k] {
			seen[k] = true
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out
}

func isKeyName(k string) bool {
	if k == "" {
		return false
	}
	c := k[0]
	if !(c == '_' || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z') {
		return false
	}
	for i := 1; i < len(k); i++ {
		c = k[i]
		if !(c == '_' || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9') {
			return false
		}
	}
	return true
}

func sha256hex(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func copyChmod(src, dst string, perm os.FileMode) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := os.WriteFile(dst, data, perm); err != nil {
		return err
	}
	return os.Chmod(dst, perm)
}

type metadata struct {
	Name string `json:"name"`
	Repo string `json:"repo"`
}

func readMetadata(path string) (metadata, error) {
	var m metadata
	data, err := os.ReadFile(path)
	if err != nil {
		return m, err
	}
	err = json.Unmarshal(data, &m)
	return m, err
}

func selected(id string) bool {
	raw, set := os.LookupEnv("ANGST_PROJECTS_ONLY")
	if !set {
		return true
	}
	for _, p := range strings.Fields(raw) {
		if p == id {
			return true
		}
	}
	return false
}

func resolve(name string) (scope.Scope, string, bool) {
	store := storeRoot()
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		metas, err := filepath.Glob(filepath.Join(store, string(s), "*", "metadata.yaml"))
		if err != nil {
			continue
		}
		for _, meta := range metas {
			m, err := readMetadata(meta)
			if err != nil {
				continue
			}
			if m.Name == name {
				return s, filepath.Base(filepath.Dir(meta)), true
			}
		}
	}
	return "", "", false
}

func sopsDecrypt(s scope.Scope, file string) ([]byte, error) {
	c := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", file)
	c.Env = append(os.Environ(), "SOPS_AGE_KEY_FILE="+scope.AgeKeyfile(s, scope.EnvOverride))
	c.Stderr = os.Stderr
	var out bytes.Buffer
	c.Stdout = &out
	if err := c.Run(); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func sopsDecryptToFile(s scope.Scope, file, out string) error {
	c := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", "--output", out, file)
	c.Env = append(os.Environ(), "SOPS_AGE_KEY_FILE="+scope.AgeKeyfile(s, scope.EnvOverride))
	c.Stderr = os.Stderr
	return c.Run()
}

func encrypt(s scope.Scope, plain, target string) error {
	recipient, err := scope.RecipientFor(s, scope.EnvOverride)
	if err != nil {
		return err
	}
	keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
	work, err := os.MkdirTemp("", "angst-encrypt-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(work)

	sopsConf := fmt.Sprintf("---\ncreation_rules:\n  - path_regex: .*\n    age: |\n      %s\n", recipient)
	if err := os.WriteFile(filepath.Join(work, ".sops.yaml"), []byte(sopsConf), 0o600); err != nil {
		return err
	}
	data, err := os.ReadFile(plain)
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(work, "plain"), data, 0o600); err != nil {
		return err
	}
	return cmd.RunDir(work, []string{"SOPS_AGE_KEY_FILE=" + keyfile},
		"sops", "-e", "--input-type", "binary", "--output-type", "binary", "--output", target, "plain")
}

func usage() {
	fmt.Print(`Usage:
  angst projects add <name> <repo> [--scope work|personal]
  angst projects sync
  angst projects status
  angst projects capture <name>
  angst projects edit-env <name>
  angst projects import [--all]
  angst projects export [--all]
  angst projects rm <name>
`)
}

func Run(args []string) int {
	cmdName := ""
	if len(args) > 0 {
		cmdName = args[0]
		args = args[1:]
	}
	switch cmdName {
	case "add":
		return cmdAdd(args)
	case "sync":
		return cmdSync(args)
	case "status":
		return cmdStatus(args)
	case "capture":
		return cmdCapture(args)
	case "edit-env":
		return cmdEditEnv(args)
	case "import":
		return cmdImport(args)
	case "export":
		return cmdExport(args)
	case "rm":
		return cmdRm(args)
	case "", "-h", "--help":
		usage()
		return exitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown projects command: %s\n", cmdName)
		usage()
		return exitUsage
	}
}

func cmdAdd(args []string) int {
	name, repo := "", ""
	s := scope.Personal
	i := 0
	for i < len(args) {
		switch args[i] {
		case "--scope":
			if i+1 >= len(args) || args[i+1] == "" {
				fmt.Fprintln(os.Stderr, "error: --scope requires a value (work|personal)")
				usage()
				return exitUsage
			}
			s = scope.Scope(args[i+1])
			i += 2
		case "-h", "--help":
			usage()
			return exitOK
		default:
			if name == "" {
				name = args[i]
			} else if repo == "" {
				repo = args[i]
			} else {
				fmt.Fprintln(os.Stderr, "error: too many arguments")
				usage()
				return exitUsage
			}
			i++
		}
	}
	if name == "" || repo == "" {
		fmt.Fprintln(os.Stderr, "error: add requires a name and a repo URL")
		usage()
		return exitUsage
	}
	if !scope.Valid(string(s)) {
		fmt.Fprintf(os.Stderr, "error: invalid scope '%s' (work|personal)\n", s)
		return exitUsage
	}
	if _, _, ok := resolve(name); ok {
		fmt.Fprintf(os.Stderr, "error: project '%s' already exists in the store\n", name)
		return exitError
	}

	store := storeRoot()
	id := randomID()
	dir := filepath.Join(store, string(s), id)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return exitError
	}
	m := metadata{Name: name, Repo: repo}
	data, _ := json.MarshalIndent(m, "", "  ")
	if err := os.WriteFile(filepath.Join(dir, "metadata.yaml"), append(data, '\n'), 0o600); err != nil {
		os.RemoveAll(dir)
		return exitError
	}
	if err := os.WriteFile(filepath.Join(dir, "env"), nil, 0o600); err != nil {
		os.RemoveAll(dir)
		return exitError
	}
	fmt.Printf("added project '%s' -> %s/%s\n", name, s, filepath.Base(dir))
	fmt.Println("  (run 'angst projects export' to push it to the encrypted repo store)")
	return exitOK
}

func randomID() string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

func cmdImport(args []string) int {
	all := false
	for _, a := range args {
		switch a {
		case "--all":
			all = true
		case "-h", "--help":
			usage()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown import option: %s\n", a)
			usage()
			return exitUsage
		}
	}

	store := storeRoot()
	repo := repoRoot()
	if _, err := os.Stat(repo); err != nil {
		fmt.Fprintf(os.Stderr, "warn: repo store not found at %s; nothing to import\n", repo)
		return exitOK
	}
	if err := os.MkdirAll(store, 0o700); err != nil {
		return exitOK
	}
	_ = os.Chmod(store, 0o700)
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(repo, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
		if _, err := os.Stat(keyfile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s age key; skipping %s import\n", s, s)
			continue
		}
		metas, _ := filepath.Glob(filepath.Join(scopePath, "*", "metadata.yaml"))
		for _, meta := range metas {
			id := filepath.Base(filepath.Dir(meta))
			if !all && !selected(id) {
				continue
			}
			if _, err := os.Stat(filepath.Join(store, string(s), id, "metadata.yaml")); err == nil {
				continue
			}
			importOne(s, id)
		}
	}
	return exitOK
}

func importOne(s scope.Scope, id string) {
	store := storeRoot()
	repo := repoRoot()
	meta := filepath.Join(repo, string(s), id, "metadata.yaml")
	if _, err := os.Stat(meta); err != nil {
		return
	}
	dir := filepath.Join(store, string(s), id)
	_ = os.MkdirAll(dir, 0o700)

	data, err := sopsDecrypt(s, meta)
	if err != nil {
		fmt.Fprintf(os.Stderr, "warn: could not decrypt %s/%s metadata; skipping\n", s, id)
		return
	}
	plain := bytes.TrimRight(data, "\n")
	_ = os.WriteFile(filepath.Join(dir, "metadata.yaml"), append(plain, '\n'), 0o600)
	_ = os.Chmod(filepath.Join(dir, "metadata.yaml"), 0o600)

	envSrc := filepath.Join(repo, string(s), id, "env")
	if _, err := os.Stat(envSrc); err == nil {
		if err := sopsDecryptToFile(s, envSrc, filepath.Join(dir, "env")); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s/%s env; skipping\n", s, id)
		} else {
			_ = os.Chmod(filepath.Join(dir, "env"), 0o600)
		}
	} else {
		_ = os.WriteFile(filepath.Join(dir, "env"), nil, 0o600)
		_ = os.Chmod(filepath.Join(dir, "env"), 0o600)
	}
	fmt.Printf("imported %s/%s\n", s, id)
}

func cmdExport(args []string) int {
	all := false
	for _, a := range args {
		switch a {
		case "--all":
			all = true
		case "-h", "--help":
			usage()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown export option: %s\n", a)
			usage()
			return exitUsage
		}
	}

	store := storeRoot()
	repo := repoRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "warn: working store not found at %s; nothing to export\n", store)
		return exitOK
	}
	_ = os.MkdirAll(repo, 0o700)

	failed := false
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(store, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
		if _, err := os.Stat(keyfile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s age key; skipping %s export\n", s, s)
			continue
		}
		metas, _ := filepath.Glob(filepath.Join(scopePath, "*", "metadata.yaml"))
		for _, meta := range metas {
			id := filepath.Base(filepath.Dir(meta))
			if !all && !selected(id) {
				continue
			}
			target := filepath.Join(repo, string(s), id)
			_ = os.MkdirAll(target, 0o700)
			if encrypt(s, meta, filepath.Join(target, "metadata.yaml")) != nil ||
				encrypt(s, filepath.Join(store, string(s), id, "env"), filepath.Join(target, "env")) != nil {
				fmt.Fprintf(os.Stderr, "error: encryption failed for %s/%s\n", s, id)
				failed = true
				continue
			}
			fmt.Printf("exported %s/%s\n", s, id)
		}
	}
	fmt.Printf("==> Exported to %s (remember to commit).\n", repo)
	if failed {
		return exitError
	}
	return exitOK
}

func cmdSync(args []string) int {
	_ = args
	store := storeRoot()
	root := projectsRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "warn: projects store not found at %s; nothing to sync\n", store)
		return exitOK
	}
	if err := os.MkdirAll(root, 0o755); err != nil {
		return exitError
	}
	_ = os.Chmod(root, 0o755)

	failed := false
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(store, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		gitSSH := "ssh -o StrictHostKeyChecking=accept-new -i " + scope.SSHKeyfile(s)
		metas, _ := filepath.Glob(filepath.Join(scopePath, "*", "metadata.yaml"))
		for _, meta := range metas {
			id := filepath.Base(filepath.Dir(meta))
			if !selected(id) {
				continue
			}
			m, err := readMetadata(meta)
			if err != nil {
				continue
			}
			if m.Name == "" {
				fmt.Fprintf(os.Stderr, "warn: empty name in %s/%s metadata; skipping\n", s, id)
				continue
			}
			target := filepath.Join(root, m.Name)
			if _, err := os.Stat(filepath.Join(target, ".git")); err != nil {
				fmt.Printf("cloning %s -> %s\n", m.Repo, target)
				if err := clone(gitSSH, m.Repo, target); err != nil {
					fmt.Fprintf(os.Stderr, "warn: clone failed for '%s'; skipping (network down?)\n", m.Name)
					continue
				}
			}
			if err := syncEnv(s, id, m.Name); err != nil {
				failed = true
			}
		}
	}
	if failed {
		return exitError
	}
	return exitOK
}

func clone(gitSSH, remote, target string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	c := exec.CommandContext(ctx, "git", "clone", remote, target)
	c.Env = append(os.Environ(), "GIT_SSH_COMMAND="+gitSSH)
	c.Stdout = nil
	c.Stderr = nil
	return c.Run()
}

func syncEnv(s scope.Scope, id, name string) error {
	store := storeRoot()
	envFile := filepath.Join(store, string(s), id, "env")
	target := filepath.Join(projectsRoot(), name, ".env")
	sd := sidecarDir()
	sidecar := filepath.Join(sd, name+".env.sha256")
	_ = os.MkdirAll(sd, 0o700)
	_ = os.Chmod(sd, 0o700)

	if _, err := os.Stat(envFile); err != nil {
		fmt.Fprintf(os.Stderr, "warn: no env in store for %s; skipping\n", name)
		return nil
	}
	storeHash := sha256hex(envFile)

	if _, err := os.Stat(target); err != nil {
		if err := copyChmod(envFile, target, 0o600); err != nil {
			return err
		}
		_ = os.WriteFile(sidecar, []byte(storeHash+"\n"), 0o644)
		fmt.Printf("materialized %s/.env\n", name)
		return nil
	}

	cur := sha256hex(target)
	last := readTrimmed(sidecar)

	if cur == storeHash {
		_ = os.WriteFile(sidecar, []byte(storeHash+"\n"), 0o644)
		return nil
	}
	if cur == last {
		if err := copyChmod(envFile, target, 0o600); err != nil {
			return err
		}
		_ = os.WriteFile(sidecar, []byte(storeHash+"\n"), 0o644)
		fmt.Printf("updated %s/.env (store changed)\n", name)
		return nil
	}

	fmt.Fprintf(os.Stderr, "stale: %s/.env was edited locally; not clobbering\n", name)
	envKeyDiff(envFile, target)
	return errStale
}

func readTrimmed(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(data), "\n")
}

func envKeyDiff(storePath, localPath string) {
	a := keys(storePath)
	b := keys(localPath)
	if len(a) == 0 && len(b) == 0 {
		return
	}
	onlyA := map[string]bool{}
	for _, k := range a {
		onlyA[k] = true
	}
	for _, k := range b {
		delete(onlyA, k)
	}
	var storeOnly []string
	for _, k := range a {
		if onlyA[k] {
			storeOnly = append(storeOnly, k)
		}
	}
	onlyB := map[string]bool{}
	for _, k := range b {
		onlyB[k] = true
	}
	for _, k := range a {
		delete(onlyB, k)
	}
	var localOnly []string
	for _, k := range b {
		if onlyB[k] {
			localOnly = append(localOnly, k)
		}
	}
	for _, k := range storeOnly {
		fmt.Fprintf(os.Stderr, "  store: %s\n", k)
	}
	for _, k := range localOnly {
		fmt.Fprintf(os.Stderr, "  local: %s\n", k)
	}
}

func cmdStatus(args []string) int {
	_ = args
	store := storeRoot()
	root := projectsRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "projects store not found at %s\n", store)
		return exitOK
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(w, "SCOPE\tID\tNAME\tREPO\tENV")
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(store, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		metas, _ := filepath.Glob(filepath.Join(scopePath, "*", "metadata.yaml"))
		for _, meta := range metas {
			id := filepath.Base(filepath.Dir(meta))
			m, err := readMetadata(meta)
			if err != nil {
				continue
			}
			target := filepath.Join(root, m.Name)
			envStatus := "no clone"
			if _, err := os.Stat(filepath.Join(target, ".git")); err == nil {
				envFile := filepath.Join(store, string(s), id, "env")
				sidecar := filepath.Join(sidecarDir(), m.Name+".env.sha256")
				if _, err := os.Stat(filepath.Join(target, ".env")); err != nil {
					envStatus = "missing"
				} else if _, err := os.Stat(envFile); err != nil {
					envStatus = "no-store-env"
				} else {
					cur := sha256hex(filepath.Join(target, ".env"))
					storeHash := sha256hex(envFile)
					last := readTrimmed(sidecar)
					switch {
					case cur == storeHash:
						envStatus = "ok"
					case cur == last:
						envStatus = "store-changed"
					default:
						envStatus = "STALE"
					}
				}
			}
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", s, id, m.Name, m.Repo, envStatus)

			if _, err := os.Stat(filepath.Join(target, ".git")); err == nil {
				exPath := filepath.Join(target, ".env.example")
				if _, err := os.Stat(exPath); err == nil {
					missing := missingKeys(exPath, filepath.Join(target, ".env"))
					if len(missing) > 0 {
						fmt.Fprintf(os.Stderr, "  .env.example vars not declared in .env: %s\n", strings.Join(missing, " "))
					}
				}
			}
		}
	}
	w.Flush()
	return exitOK
}

func missingKeys(examplePath, envPath string) []string {
	a := keys(examplePath)
	b := keys(envPath)
	set := map[string]bool{}
	for _, k := range b {
		set[k] = true
	}
	var out []string
	for _, k := range a {
		if !set[k] {
			out = append(out, k)
		}
	}
	return out
}

func cmdCapture(args []string) int {
	if len(args) != 1 {
		usage()
		return exitUsage
	}
	name := args[0]
	s, id, ok := resolve(name)
	if !ok {
		return unknownProject(name)
	}
	src := filepath.Join(projectsRoot(), name, ".env")
	if _, err := os.Stat(src); err != nil {
		fmt.Fprintf(os.Stderr, "error: no %s to capture\n", src)
		return exitError
	}
	store := storeRoot()
	target := filepath.Join(store, string(s), id, "env")
	if err := copyChmod(src, target, 0o600); err != nil {
		return exitError
	}
	sd := sidecarDir()
	_ = os.MkdirAll(sd, 0o700)
	_ = os.WriteFile(filepath.Join(sd, name+".env.sha256"), []byte(sha256hex(src)+"\n"), 0o644)
	fmt.Printf("captured %s (scope %s)\n", name, s)
	fmt.Println("  (run 'angst projects export' to push it to the encrypted repo store)")
	return exitOK
}

func unknownProject(name string) int {
	fmt.Fprintf(os.Stderr, "error: unknown project '%s'\n", name)
	return exitError
}

func cmdEditEnv(args []string) int {
	if len(args) != 1 {
		usage()
		return exitUsage
	}
	name := args[0]
	s, id, ok := resolve(name)
	if !ok {
		return unknownProject(name)
	}
	store := storeRoot()
	envFile := filepath.Join(store, string(s), id, "env")
	if _, err := os.Stat(envFile); err != nil {
		fmt.Fprintf(os.Stderr, "error: no env in store for %s\n", name)
		return exitError
	}

	f, err := os.CreateTemp("", "angst-env-")
	if err != nil {
		return exitError
	}
	tmpPath := f.Name()
	_ = f.Close()
	if err := copyChmod(envFile, tmpPath, 0o600); err != nil {
		return exitError
	}

	editor := strings.Fields(os.Getenv("EDITOR"))
	if len(editor) == 0 {
		editor = []string{"vi"}
	}
	edArgs := append(append([]string{}, editor[1:]...), tmpPath)
	c := exec.Command(editor[0], edArgs...)
	c.Stdin = os.Stdin
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	if err := c.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "edit aborted; store unchanged")
		_ = os.Remove(tmpPath)
		return exitError
	}
	if err := copyChmod(tmpPath, envFile, 0o600); err != nil {
		_ = os.Remove(tmpPath)
		return exitError
	}
	_ = os.Remove(tmpPath)
	fmt.Printf("updated %s env (scope %s)\n", name, s)
	fmt.Println("  (run 'angst projects export' to push it to the encrypted repo store)")

	target := filepath.Join(projectsRoot(), name, ".env")
	sidecar := filepath.Join(sidecarDir(), name+".env.sha256")
	if _, err := os.Stat(target); err == nil {
		if _, err := os.Stat(sidecar); err == nil {
			if sha256hex(target) == readTrimmed(sidecar) {
				if err := copyChmod(envFile, target, 0o600); err == nil {
					_ = os.WriteFile(sidecar, []byte(sha256hex(target)+"\n"), 0o644)
					fmt.Printf("resynced %s/.env\n", name)
				}
			}
		}
	}
	return exitOK
}

func cmdRm(args []string) int {
	if len(args) != 1 {
		usage()
		return exitUsage
	}
	name := args[0]
	s, id, ok := resolve(name)
	if !ok {
		return unknownProject(name)
	}
	store := storeRoot()
	if s != "" && id != "" {
		_ = os.RemoveAll(filepath.Join(store, string(s), id))
	}
	repo := repoRoot()
	_ = os.RemoveAll(filepath.Join(repo, string(s), id))
	_ = os.Remove(filepath.Join(sidecarDir(), name+".env.sha256"))
	fmt.Printf("removed project '%s' (%s/%s)\n", name, s, id)
	return exitOK
}
