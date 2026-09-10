package db

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/paths"
	"angst/internal/shared"
)

func storeRoot() string {
	if v := os.Getenv("ANGST_DB_STORE"); v != "" {
		return v
	}
	return filepath.Join(shared.Home(), ".secrets", "db")
}

func repoRoot() string {
	if v := os.Getenv("ANGST_DB_REPO"); v != "" {
		return v
	}
	return filepath.Join(paths.RepoRoot(), "secrets", "db")
}

func configHome() string {
	if v := os.Getenv("XDG_CONFIG_HOME"); v != "" {
		return v
	}
	return filepath.Join(shared.Home(), ".config")
}

func sqlitConnectionsPath() string {
	return filepath.Join(configHome(), "sqlit", "connections.json")
}

func rainfrogConfigPath() string {
	return filepath.Join(configHome(), "rainfrog", "rainfrog_config.toml")
}

type scopedSlug struct {
	scope string
	id    string
	raw   string
}

func parseScopedSlug(raw string) (scopedSlug, error) {
	idx := strings.IndexByte(raw, '/')
	if idx <= 0 {
		return scopedSlug{}, fmt.Errorf("db slug %q must be scoped like \"personal/my-pg\" or \"work/analytics\"", raw)
	}
	scope := raw[:idx]
	id := raw[idx+1:]
	if scope != "personal" && scope != "work" {
		return scopedSlug{}, fmt.Errorf("db slug %q has unknown scope %q (expected personal or work)", raw, scope)
	}
	if strings.TrimSpace(id) == "" {
		return scopedSlug{}, fmt.Errorf("db slug %q has empty id", raw)
	}
	if strings.Contains(id, "..") {
		return scopedSlug{}, fmt.Errorf("db slug %q contains \"..\"", raw)
	}
	return scopedSlug{scope: scope, id: id, raw: raw}, nil
}

func selectedSlugs() []string {
	raw, set := os.LookupEnv("ANGST_DB_ONLY")
	if !set {
		return nil
	}
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	return strings.Fields(raw)
}

func isSelected(raw string) bool {
	sel := selectedSlugs()
	if sel == nil {
		return true
	}
	for _, s := range sel {
		if s == raw {
			return true
		}
	}
	return false
}

type connection struct {
	Type     string `json:"type"`
	Host     string `json:"host,omitempty"`
	Port     *int   `json:"port,omitempty"`
	Database string `json:"database,omitempty"`
	Username string `json:"username,omitempty"`
	Password string `json:"password,omitempty"`
	Path     string `json:"path,omitempty"`
	Default  bool   `json:"default,omitempty"`
	Name     string `json:"name,omitempty"`
}

func loadConnection(scope, id string) (connection, error) {
	p := filepath.Join(storeRoot(), scope, id, "connection.json")
	data, err := os.ReadFile(p)
	if err != nil {
		return connection{}, err
	}
	var c connection
	if err := json.Unmarshal(data, &c); err != nil {
		return connection{}, fmt.Errorf("parsing %s: %w", p, err)
	}
	return c, nil
}

func discoverAllSlugs() []scopedSlug {
	var out []scopedSlug
	root := storeRoot()
	for _, scope := range []string{"personal", "work"} {
		base := filepath.Join(root, scope)
		_ = filepath.WalkDir(base, func(path string, d os.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			if d.Name() != "connection.json" {
				return nil
			}
			dir := filepath.Dir(path)
			rel, rerr := filepath.Rel(base, dir)
			if rerr != nil || rel == "." {
				return nil
			}
			raw := scope + "/" + filepath.ToSlash(rel)
			out = append(out, scopedSlug{scope: scope, id: rel, raw: raw})
			return nil
		})
	}
	return out
}

func usage() {
	fmt.Print(`Usage:
  angst db import
  angst db sync
`)
}
func Run(args []string) int {
	cmdName := ""
	if len(args) > 0 {
		cmdName = args[0]
		args = args[1:]
	}
	switch cmdName {
	case "import":
		return cmdImport(args)
	case "sync":
		return cmdSync(args)
	case "", "-h", "--help":
		usage()
		return shared.ExitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown db command: %s\n", cmdName)
		usage()
		return shared.ExitUsage
	}
}
