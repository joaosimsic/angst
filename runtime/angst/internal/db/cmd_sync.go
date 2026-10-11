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
	"postgres":    "postgres",
	"redshift":    "postgres",
	"cockroachdb": "postgres",
	"mysql":       "mysql",
	"mariadb":     "mysql",
	"sqlite":      "sqlite",
	"oracle":      "oracle",
	"duckdb":      "duckdb",
	// NOTE: mssql has no rainfrog driver — entries are skipped for rainfrog
	// (sqlit still gets them) with a warning.
}

// defaultPortForType returns the conventional default port for a db type.
// Used by both sqlit and rainfrog writers when the vault entry omits `port`.
func defaultPortForType(connType string) int {
	switch connType {
	case "mysql", "mariadb":
		return 3306
	case "oracle":
		return 1521
	case "mssql":
		return 1433
	case "redshift":
		return 5439
	case "cockroachdb":
		return 26257
	default: // postgres + unknown tcp types
		return 5432
	}
}

func effectivePort(c connection) int {
	if c.Port != nil {
		return *c.Port
	}
	return defaultPortForType(c.Type)
}

// encodeRainfrogPassword percent-encodes a password the same way rainfrog does
// (src/config.rs StructuredConnection::connection_string):
// utf8_percent_encode(password, FRAGMENT) where FRAGMENT = CONTROLS +
// ' ' '"' '<' '>' '`' '#' '{' '}' '|' '^' '\' '[' ']' '$' '&' '(' ')' ':'
// ';' '=' '?' '@' '!' '~' '\” '*' '+' ',' '/'.
// We additionally encode '%' itself (upstream omits it, which corrupts
// passwords containing a literal '%' or "%XX") and all non-ASCII bytes, both
// of which still decode to the original password.
func encodeRainfrogPassword(s string) string {
	const hex = "0123456789ABCDEF"
	var b strings.Builder
	b.Grow(len(s) + 8)
	for i := 0; i < len(s); i++ {
		c := s[i]
		encode := c < 0x20 || c == 0x7F || c >= 0x80
		if !encode {
			switch c {
			case ' ', '"', '<', '>', '`', '#', '{', '}', '|', '^', '\\',
				'[', ']', '$', '&', '(', ')', ':', ';', '=', '?', '@',
				'!', '~', '\'', '*', '+', ',', '/', '%':
				encode = true
			}
		}
		if !encode {
			b.WriteByte(c)
			continue
		}
		b.WriteByte('%')
		b.WriteByte(hex[c>>4])
		b.WriteByte(hex[c&0x0F])
	}
	return b.String()
}

// tomlEscape escapes a string for use inside a TOML basic string ("...").
func tomlEscape(s string) string {
	r := strings.NewReplacer(
		`\`, `\\`,
		`"`, `\"`,
		"\n", `\n`,
		"\r", `\r`,
		"\t", `\t`,
	)
	return r.Replace(s)
}

// tomlKey renders a [db] entry name as a TOML key. Bare keys are used when
// safe; otherwise the name is quoted to avoid `.' creating subtables or
// spaces/slashes breaking the parse.
func tomlKey(name string) string {
	if name == "" {
		return `""`
	}
	isBare := true
	for _, r := range name {
		if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' || r == '-' {
			continue
		}
		isBare = false
		break
	}
	if isBare {
		return name
	}
	return `"` + tomlEscape(name) + `"`
}

// rainfrogConnectionURL builds the Raw connection_string for entries that
// carry a password. It returns driver, url, true on success. File-based types
// (sqlite/duckdb) ignore the password. mssql and unknown types return false.
func rainfrogConnectionURL(e syncEntry, port int) (string, string, bool) {
	c := e.conn
	switch c.Type {
	case "postgres", "redshift", "cockroachdb":
		enc := encodeRainfrogPassword(c.Password)
		return "postgres", fmt.Sprintf("postgresql://%s:%s@%s:%d/%s", c.Username, enc, c.Host, port, c.Database), true
	case "mysql", "mariadb":
		enc := encodeRainfrogPassword(c.Password)
		return "mysql", fmt.Sprintf("mysql://%s:%s@%s:%d/%s", c.Username, enc, c.Host, port, c.Database), true
	case "oracle":
		enc := encodeRainfrogPassword(c.Password)
		return "oracle", fmt.Sprintf("jdbc:oracle:thin:%s/%s@//%s:%d/%s", c.Username, enc, c.Host, port, c.Database), true
	default:
		return "", "", false
	}
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
	if c.Type == "sqlite" || c.Type == "duckdb" {
		if strings.TrimSpace(c.Path) == "" {
			return fmt.Errorf("%s requires 'path'", c.Type)
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
		if e.conn.Type == "sqlite" || e.conn.Type == "duckdb" {
			connMap = map[string]interface{}{
				"name":    e.name,
				"db_type": dbType,
				"endpoint": map[string]interface{}{
					"kind": "file",
					"path": e.conn.Path,
				},
			}
		} else {
			port := effectivePort(e.conn)
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
				fmt.Fprintf(os.Stderr, "warn: type %q has no rainfrog driver; skipping %q for rainfrog (sqlit kept)\n", e.conn.Type, e.slug.raw)
				continue
			}
			defaultFlag := ""
			if e.conn.Default {
				defaultFlag = ", default = true"
			}
			key := tomlKey(e.name)
			if e.conn.Type == "sqlite" {
				escaped := tomlEscape(e.conn.Path)
				fmt.Fprintf(&b, "%s = { connection_string = \"sqlite://%s\", driver = \"sqlite\"%s }\n", key, escaped, defaultFlag)
				continue
			}
			if e.conn.Type == "duckdb" {
				escaped := tomlEscape(e.conn.Path)
				fmt.Fprintf(&b, "%s = { connection_string = \"duckdb://%s\", driver = \"duckdb\"%s }\n", key, escaped, defaultFlag)
				continue
			}
			port := effectivePort(e.conn)
			if e.conn.Password != "" {
				// Structured entries always prompt via keyring (rainfrog
				// ignores `password =`). Embed the password in a Raw
				// connection_string so rainfrog connects without prompting.
				// File is 0600 (see atomicWrite).
				urlDriver, url, ok := rainfrogConnectionURL(e, port)
				if !ok {
					fmt.Fprintf(os.Stderr, "warn: could not build rainfrog connection_string for %q; skipping for rainfrog\n", e.slug.raw)
					continue
				}
				// urlDriver matches driver for aliased types (mariadb->mysql,
				// redshift/cockroach->postgres); use the resolved driver.
				_ = driver
				fmt.Fprintf(&b, "%s = { connection_string = \"%s\", driver = \"%s\"%s }\n", key, tomlEscape(url), urlDriver, defaultFlag)
				continue
			}
			escHost := tomlEscape(e.conn.Host)
			escDB := tomlEscape(e.conn.Database)
			escUser := tomlEscape(e.conn.Username)
			fmt.Fprintf(&b, "%s = { host = \"%s\", port = %d, database = \"%s\", username = \"%s\", driver = \"%s\"%s }\n", key, escHost, port, escDB, escUser, driver, defaultFlag)
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
