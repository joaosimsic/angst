package db

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/shared"
)

var sqlitDbTypes = map[string]string{
	"postgres":    "postgresql",
	"mysql":       "mysql",
	"sqlite":      "sqlite",
	"oracle":      "oracle",
	"mssql":       "mssql",
	"mariadb":     "mariadb",
	"duckdb":      "duckdb",
	"redshift":    "redshift",
	"cockroachdb": "cockroachdb",
}

var rainfrogDrivers = map[string]string{
	"postgres": "postgres",
	"mysql":    "mysql",
	"sqlite":   "sqlite",
	"oracle":   "oracle",
	"duckdb":   "duckdb",
}

type syncEntry struct {
	slug scopedSlug
	conn connection
	name string
}

func cmdSync(args []string) int {
	for _, a := range args {
		switch a {
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown sync option: %s\n", a)
			usage()
			return shared.ExitUsage
		}
	}

	store := storeRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "warn: db store not found at %s; nothing to sync\n", store)
		if err := writeEmptyConfigs(); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not write empty db configs: %v\n", err)
		}
		return shared.ExitOK
	}

	var toSync []scopedSlug
	if sel := selectedSlugs(); sel != nil {
		for _, raw := range sel {
			ss, err := parseScopedSlug(raw)
			if err != nil {
				fmt.Fprintf(os.Stderr, "warn: skipping invalid db slug %q: %v\n", raw, err)
				continue
			}
			toSync = append(toSync, ss)
		}
	} else {
		toSync = discoverAllSlugs()
	}

	seen := map[string]bool{}
	var uniq []scopedSlug
	for _, s := range toSync {
		if !seen[s.raw] {
			seen[s.raw] = true
			uniq = append(uniq, s)
		}
	}
	toSync = uniq

	var entries []syncEntry
	for _, ss := range toSync {
		if !isSelected(ss.raw) {
			continue
		}
		c, err := loadConnection(ss.scope, ss.id)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not load db %q: %v; skipping\n", ss.raw, err)
			continue
		}
		if err := validateConnection(c, ss.raw); err != nil {
			fmt.Fprintf(os.Stderr, "warn: invalid db %q: %v; skipping\n", ss.raw, err)
			continue
		}
		name := c.Name
		if name == "" {
			name = filepath.Base(ss.id)
		}
		entries = append(entries, syncEntry{slug: ss, conn: c, name: name})
	}

	if err := writeSqlitConfig(entries); err != nil {
		fmt.Fprintf(os.Stderr, "warn: could not write sqlit config: %v\n", err)
		return shared.ExitError
	}
	if err := writeRainfrogConfig(entries); err != nil {
		fmt.Fprintf(os.Stderr, "warn: could not write rainfrog config: %v\n", err)
		return shared.ExitError
	}
	return shared.ExitOK
}

func validateConnection(c connection, raw string) error {
	if c.Type == "" {
		return fmt.Errorf("missing 'type'")
	}
	if _, ok := sqlitDbTypes[c.Type]; !ok {
		if _, ok2 := rainfrogDrivers[c.Type]; !ok2 {
			return fmt.Errorf("unsupported type %q", c.Type)
		}
	}
	if c.Type == "sqlite" {
		if strings.TrimSpace(c.Path) == "" {
			return fmt.Errorf("sqlite requires 'path'")
		}
	} else {
		if strings.TrimSpace(c.Host) == "" {
			return fmt.Errorf("type %q requires 'host'", c.Type)
		}
		if strings.TrimSpace(c.Database) == "" {
			return fmt.Errorf("type %q requires 'database'", c.Type)
		}
		if strings.TrimSpace(c.Username) == "" {
			return fmt.Errorf("type %q requires 'username'", c.Type)
		}
	}
	return nil
}

func writeEmptyConfigs() error {
	if err := writeSqlitConfig(nil); err != nil {
		return err
	}
	if err := writeRainfrogConfig(nil); err != nil {
		return err
	}
	return nil
}

func writeSqlitConfig(entries []syncEntry) error {
	conns := []map[string]interface{}{}
	for _, e := range entries {
		dbType, ok := sqlitDbTypes[e.conn.Type]
		if !ok {
			continue
		}
		var connMap map[string]interface{}
		if e.conn.Type == "sqlite" {
			connMap = map[string]interface{}{
				"name":    e.name,
				"db_type": dbType,
				"endpoint": map[string]interface{}{
					"kind": "file",
					"path": e.conn.Path,
				},
			}
		} else {
			port := 5432
			if e.conn.Port != nil {
				port = *e.conn.Port
			}
			endpoint := map[string]interface{}{
				"kind":     "tcp",
				"host":     e.conn.Host,
				"database": e.conn.Database,
				"username": e.conn.Username,
				"port":     fmt.Sprintf("%d", port),
			}
			if e.conn.Password != "" {
				endpoint["password"] = e.conn.Password
			}
			connMap = map[string]interface{}{
				"name":     e.name,
				"db_type":  dbType,
				"endpoint": endpoint,
			}
		}
		conns = append(conns, connMap)
	}
	payload := map[string]interface{}{
		"version":     2,
		"connections": conns,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	dest := sqlitConnectionsPath()
	if err := atomicWrite(dest, append(data, '\n'), 0o600); err != nil {
		return err
	}
	return nil
}

func writeRainfrogConfig(entries []syncEntry) error {
	settingsText := `[settings]
mouse_mode = true
data_compact_columns = true
data_row_spacer = false
autocomplete_enabled = true
autocomplete_debounce_ms = 100
autocomplete_trigger_len = 1
autopairs_enabled = true
`
	var b strings.Builder
	b.WriteString(settingsText)
	if len(entries) > 0 {
		b.WriteString("\n[db]\n")
		for _, e := range entries {
			driver, ok := rainfrogDrivers[e.conn.Type]
			if !ok {
				continue
			}
			defaultFlag := ""
			if e.conn.Default {
				defaultFlag = ", default = true"
			}
			if e.conn.Type == "sqlite" {
				escaped := strings.ReplaceAll(e.conn.Path, `"`, `\"`)
				fmt.Fprintf(&b, "%s = { connection_string = \"sqlite://%s\", driver = \"sqlite\"%s }\n", e.name, escaped, defaultFlag)
			} else {
				port := 5432
				if e.conn.Port != nil {
					port = *e.conn.Port
				}
				passPart := ""
				if e.conn.Password != "" {
					esc := strings.ReplaceAll(e.conn.Password, `"`, `\"`)
					passPart = fmt.Sprintf(`, password = "%s"`, esc)
				}
				escHost := strings.ReplaceAll(e.conn.Host, `"`, `\"`)
				escDB := strings.ReplaceAll(e.conn.Database, `"`, `\"`)
				escUser := strings.ReplaceAll(e.conn.Username, `"`, `\"`)
				fmt.Fprintf(&b, "%s = { host = \"%s\", port = %d, database = \"%s\", username = \"%s\", driver = \"%s\"%s%s }\n", e.name, escHost, port, escDB, escUser, driver, passPart, defaultFlag)
			}
		}
	}
	dest := rainfrogConfigPath()
	return atomicWrite(dest, []byte(b.String()), 0o600)
}

func atomicWrite(dest string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(dest)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	tmp := dest + ".tmp"
	if err := os.WriteFile(tmp, data, perm); err != nil {
		return err
	}
	if err := os.Chmod(tmp, perm); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, dest); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return os.Chmod(dest, perm)
}
