package projects

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"angst/internal/shared"
	"angst/internal/scope"
)

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
				return shared.ExitUsage
			}
			s = scope.Scope(args[i+1])
			i += 2
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			if name == "" {
				name = args[i]
			} else if repo == "" {
				repo = args[i]
			} else {
				fmt.Fprintln(os.Stderr, "error: too many arguments")
				usage()
				return shared.ExitUsage
			}
			i++
		}
	}
	if name == "" || repo == "" {
		fmt.Fprintln(os.Stderr, "error: add requires a name and a repo URL")
		usage()
		return shared.ExitUsage
	}
	if !scope.Valid(string(s)) {
		fmt.Fprintf(os.Stderr, "error: invalid scope '%s' (work|personal)\n", s)
		return shared.ExitUsage
	}
	if _, _, ok := resolve(name); ok {
		fmt.Fprintf(os.Stderr, "error: project '%s' already exists in the store\n", name)
		return shared.ExitError
	}

	store := storeRoot()
	id := randomID()
	dir := filepath.Join(store, string(s), id)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return shared.ExitError
	}
	m := metadata{Name: name, Repo: repo}
	data, _ := json.MarshalIndent(m, "", "  ")
	if err := os.WriteFile(filepath.Join(dir, "metadata.yaml"), append(data, '\n'), 0o600); err != nil {
		os.RemoveAll(dir)
		return shared.ExitError
	}
	if err := os.WriteFile(filepath.Join(dir, "env"), nil, 0o600); err != nil {
		os.RemoveAll(dir)
		return shared.ExitError
	}
	fmt.Printf("added project '%s' -> %s/%s\n", name, s, filepath.Base(dir))
	fmt.Println("  (run 'angst projects export' to push it to the encrypted repo store)")
	return shared.ExitOK
}

func cmdStatus(args []string) int {
	_ = args
	store := storeRoot()
	root := projectsRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "projects store not found at %s\n", store)
		return shared.ExitOK
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
	return shared.ExitOK
}

func cmdCapture(args []string) int {
	if len(args) != 1 {
		usage()
		return shared.ExitUsage
	}
	name := args[0]
	s, id, ok := resolve(name)
	if !ok {
		return unknownProject(name)
	}
	src := filepath.Join(projectsRoot(), name, ".env")
	if _, err := os.Stat(src); err != nil {
		fmt.Fprintf(os.Stderr, "error: no %s to capture\n", src)
		return shared.ExitError
	}
	store := storeRoot()
	target := filepath.Join(store, string(s), id, "env")
	if err := copyChmod(src, target, 0o600); err != nil {
		return shared.ExitError
	}
	sd := sidecarDir()
	_ = os.MkdirAll(sd, 0o700)
	_ = os.WriteFile(filepath.Join(sd, name+".env.sha256"), []byte(sha256hex(src)+"\n"), 0o644)
	fmt.Printf("captured %s (scope %s)\n", name, s)
	fmt.Println("  (run 'angst projects export' to push it to the encrypted repo store)")
	return shared.ExitOK
}

func cmdEditEnv(args []string) int {
	if len(args) != 1 {
		usage()
		return shared.ExitUsage
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
		return shared.ExitError
	}

	f, err := os.CreateTemp("", "angst-env-")
	if err != nil {
		return shared.ExitError
	}
	tmpPath := f.Name()
	_ = f.Close()
	if err := copyChmod(envFile, tmpPath, 0o600); err != nil {
		return shared.ExitError
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
		return shared.ExitError
	}
	if err := copyChmod(tmpPath, envFile, 0o600); err != nil {
		_ = os.Remove(tmpPath)
		return shared.ExitError
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
	return shared.ExitOK
}

func cmdRm(args []string) int {
	if len(args) != 1 {
		usage()
		return shared.ExitUsage
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
	return shared.ExitOK
}
