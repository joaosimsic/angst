package projects

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/paths"
	"angst/internal/shared"
	"angst/internal/scope"
)

var errStale = errors.New("stale env")

func storeRoot() string {
	if v := os.Getenv("ANGST_PROJECTS_STORE"); v != "" {
		return v
	}
	if v := os.Getenv("ANGST_PROJECTS_STORE_DEFAULT"); v != "" {
		return v
	}
	return filepath.Join(shared.Home(), ".secrets", "projects")
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
	return filepath.Join(shared.Home(), "projects")
}

func sidecarDir() string {
	return filepath.Join(shared.Home(), ".secrets", "projects")
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
		return shared.ExitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown projects command: %s\n", cmdName)
		usage()
		return shared.ExitUsage
	}
}
