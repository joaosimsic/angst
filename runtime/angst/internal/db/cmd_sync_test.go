package db

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func intPtr(v int) *int { return &v }

func writeRainfrogTo(t *testing.T, entries []syncEntry) string {
	t.Helper()
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	// isolate HOME too (configHome prefers XDG_CONFIG_HOME, but be safe)
	t.Setenv("HOME", t.TempDir())
	if err := writeRainfrogConfig(entries); err != nil {
		t.Fatalf("writeRainfrogConfig: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(cfg, "rainfrog", "rainfrog_config.toml"))
	if err != nil {
		t.Fatalf("read rainfrog config: %v", err)
	}
	if st, err := os.Stat(filepath.Join(cfg, "rainfrog", "rainfrog_config.toml")); err != nil {
		t.Fatal(err)
	} else if st.Mode().Perm() != 0o600 {
		t.Fatalf("perm = %#o, want 600", st.Mode().Perm())
	}
	return string(data)
}

func TestEncodeRainfrogPassword(t *testing.T) {
	cases := []struct{ in, want string }{
		{"simple", "simple"},
		{"abcXYZ019-_.", "abcXYZ019-_."}, {"p@ss", "p%40ss"},
		{"a/b:c?d&e=f", "a%2Fb%3Ac%3Fd%26e%3Df"},
		{"a b", "a%20b"},
		{`q"u`, "q%22u"},
		{"100%", "100%25"},
		{"a+b", "a%2Bb"},
	}
	// fix the trivial second case (no encoding expected for unreserved run)
	for _, c := range cases {
		if got := encodeRainfrogPassword(c.in); got != c.want {
			t.Errorf("encode %q = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestPostgresPasswordUsesConnectionString(t *testing.T) {
	out := writeRainfrogTo(t, []syncEntry{{
		slug: scopedSlug{scope: "personal", id: "my-pg", raw: "personal/my-pg"},
		name: "my-pg",
		conn: connection{Type: "postgres", Host: "db.local", Database: "app", Username: "bob", Password: "s3cret"},
	}})
	if strings.Contains(out, "password =") {
		t.Fatalf("output must not contain `password =`:\n%s", out)
	}
	if !strings.Contains(out, `connection_string = "postgresql://bob:s3cret@db.local:5432/app"`) {
		t.Fatalf("missing expected postgresql URL:\n%s", out)
	}
	if !strings.Contains(out, `driver = "postgres"`) {
		t.Fatalf("missing driver:\n%s", out)
	}
}

func TestPasswordSpecialCharsEncoded(t *testing.T) {
	out := writeRainfrogTo(t, []syncEntry{{
		slug: scopedSlug{scope: "personal", id: "my-pg", raw: "personal/my-pg"},
		name: "my-pg",
		conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p@ss/w:rd?x&y foo"},
	}})
	want := `postgresql://u:p%40ss%2Fw%3Ard%3Fx%26y%20foo@h:5432/d`
	if !strings.Contains(out, want) {
		t.Fatalf("want %q in:\n%s", want, out)
	}
}

func TestNoPasswordKeepsStructured(t *testing.T) {
	out := writeRainfrogTo(t, []syncEntry{{
		slug: scopedSlug{scope: "personal", id: "nopass", raw: "personal/nopass"},
		name: "nopass",
		conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u"},
	}})
	if strings.Contains(out, "connection_string") {
		t.Fatalf("passwordless entry must stay structured:\n%s", out)
	}
	if !strings.Contains(out, `host = "h"`) {
		t.Fatalf("missing structured host:\n%s", out)
	}
}

func TestAllDriversWithPassword(t *testing.T) {
	entries := []syncEntry{
		{slug: scopedSlug{raw: "personal/pg"}, name: "pg", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "personal/my"}, name: "my", conn: connection{Type: "mysql", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "personal/maria"}, name: "maria", conn: connection{Type: "mariadb", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "personal/red"}, name: "red", conn: connection{Type: "redshift", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "personal/cock"}, name: "cock", conn: connection{Type: "cockroachdb", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "personal/ora"}, name: "ora", conn: connection{Type: "oracle", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "personal/lite"}, name: "lite", conn: connection{Type: "sqlite", Path: "/tmp/a.db"}},
		{slug: scopedSlug{raw: "personal/duck"}, name: "duck", conn: connection{Type: "duckdb", Path: "/tmp/a.duckdb"}},
	}
	out := writeRainfrogTo(t, entries)
	for _, want := range []string{
		`pg = { connection_string = "postgresql://`,
		`driver = "postgres"`,
		`my = { connection_string = "mysql://`,
		`maria = { connection_string = "mysql://`,
		`driver = "mysql"`,
		`red = { connection_string = "postgresql://`,
		`cock = { connection_string = "postgresql://`,
		`ora = { connection_string = "jdbc:oracle:thin:u/p@//h:1521/d"`,
		`driver = "oracle"`,
		`lite = { connection_string = "sqlite:///tmp/a.db"`,
		`duck = { connection_string = "duckdb:///tmp/a.duckdb"`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("want %q in:\n%s", want, out)
		}
	}
	if strings.Contains(out, "password =") {
		t.Errorf("no `password =` allowed:\n%s", out)
	}
	// aliased types must resolve to a real rainfrog driver
	if strings.Contains(out, `driver = "mariadb"`) || strings.Contains(out, `driver = "redshift"`) || strings.Contains(out, `driver = "cockroachdb"`) {
		t.Errorf("aliased driver leaked:\n%s", out)
	}
}

func TestMssqlSkippedForRainfrog(t *testing.T) {
	out := writeRainfrogTo(t, []syncEntry{{
		slug: scopedSlug{scope: "personal", id: "ms", raw: "personal/ms"},
		name: "ms",
		conn: connection{Type: "mssql", Host: "h", Database: "d", Username: "u", Password: "p"},
	}})
	if strings.Contains(out, "ms = {") {
		t.Fatalf("mssql must be skipped for rainfrog:\n%s", out)
	}
}

func TestDefaultPorts(t *testing.T) {
	out := writeRainfrogTo(t, []syncEntry{
		{slug: scopedSlug{raw: "p/pg"}, name: "pg", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "p/my"}, name: "my", conn: connection{Type: "mysql", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "p/ora"}, name: "ora", conn: connection{Type: "oracle", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "p/red"}, name: "red", conn: connection{Type: "redshift", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "p/cock"}, name: "cock", conn: connection{Type: "cockroachdb", Host: "h", Database: "d", Username: "u", Password: "p"}},
		{slug: scopedSlug{raw: "p/np"}, name: "np", conn: connection{Type: "mysql", Host: "h", Database: "d", Username: "u"}},
		{slug: scopedSlug{raw: "p/custom"}, name: "custom", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p", Port: intPtr(9999)}},
	})
	for _, want := range []string{
		"postgresql://u:p@h:5432/d",
		"mysql://u:p@h:3306/d",
		"jdbc:oracle:thin:u/p@//h:1521/d",
		"postgresql://u:p@h:5439/d",
		"postgresql://u:p@h:26257/d",
		`np = { host = "h", port = 3306,`,
		"postgresql://u:p@h:9999/d",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("want %q in:\n%s", want, out)
		}
	}
}

func TestDefaultFlagPreservedNoAutoDefault(t *testing.T) {
	out := writeRainfrogTo(t, []syncEntry{
		{slug: scopedSlug{raw: "p/a"}, name: "a", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p", Default: true}},
		{slug: scopedSlug{raw: "p/b"}, name: "b", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p"}},
	})
	if !strings.Contains(out, `a = { connection_string = "postgresql://u:p@h:5432/d", driver = "postgres", default = true }`) {
		t.Fatalf("default flag lost:\n%s", out)
	}
	bLine := ""
	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, "b =") {
			bLine = line
		}
	}
	if bLine == "" || strings.Contains(bLine, "default") {
		t.Fatalf("non-default entry must not gain default:\n%s", out)
	}
	// no entry has default → no default emitted at all (selection prompt expected)
	out2 := writeRainfrogTo(t, []syncEntry{
		{slug: scopedSlug{raw: "p/a"}, name: "a", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p"}},
	})
	if strings.Contains(out2, "default = true") {
		t.Fatalf("must not auto-assign default:\n%s", out2)
	}
}

func TestTomlKeyQuoting(t *testing.T) {
	if got := tomlKey("my-pg_1"); got != "my-pg_1" {
		t.Fatalf("bare key = %q", got)
	}
	if got := tomlKey("my.db"); got != `"my.db"` {
		t.Fatalf("dotted key = %q", got)
	}
	out := writeRainfrogTo(t, []syncEntry{{
		slug: scopedSlug{raw: "p/x"}, name: "my.db", conn: connection{Type: "postgres", Host: "h", Database: "d", Username: "u", Password: "p"},
	}})
	if !strings.Contains(out, `"my.db" = { connection_string`) {
		t.Fatalf("quoted key missing:\n%s", out)
	}
}

func TestValidateDuckdbRequiresPath(t *testing.T) {
	if err := validateConnection(connection{Type: "duckdb"}, "personal/x"); err == nil {
		t.Fatalf("duckdb without path should fail")
	}
	if err := validateConnection(connection{Type: "duckdb", Path: "/tmp/a.duckdb"}, "personal/x"); err != nil {
		t.Fatalf("duckdb with path: %v", err)
	}
}
