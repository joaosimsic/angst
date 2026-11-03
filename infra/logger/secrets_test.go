package logger_test

import (
	"io/fs"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/joaosimsic/angst/infra/logger"
)

// fixtureSlugs mirrors the secrets/ stub inventory. loadSecretsSlugs guards drift.
func fixtureSlugs() []string {
	return []string{"cursor-api-key", "example", "opencode-go-key", "personal.ed25519", "work.ed25519"}
}

func stripSecretSuffix(filename string) string {
	for _, suffix := range []string{".placeholder", ".age", ".pub"} {
		filename = strings.TrimSuffix(filename, suffix)
	}

	return filename
}

func loadSecretsSlugs(t *testing.T) []string {
	t.Helper()
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("repo root: %v", err)
	}

	var slugs []string
	err = filepath.WalkDir(filepath.Join(root, "secrets"), func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}

		name := entry.Name()
		if !strings.HasSuffix(name, ".age") && !strings.HasSuffix(name, ".placeholder") && !strings.HasSuffix(name, ".pub") {
			return nil
		}

		slugs = append(slugs, stripSecretSuffix(name))

		return nil
	})
	if err != nil {
		t.Fatalf("walk secrets/: %v", err)
	}

	return uniqueSorted(slugs)
}

func uniqueSorted(values []string) []string {
	result := slices.Clone(values)

	slices.Sort(result)

	return slices.Compact(result)
}

func TestSecretsInventoryNoDrift(t *testing.T) {
	if got, want := loadSecretsSlugs(t), fixtureSlugs(); !reflect.DeepEqual(got, want) {
		t.Fatalf("secrets/ inventory drift: dir=%v fixture=%v (update fixture + Nix tests together)", got, want)
	}
}

func TestIsKnownSecretRefExact(t *testing.T) {
	slugs := fixtureSlugs()

	for _, slug := range []string{"opencode-go-key", "cursor-api-key", "example", "personal.ed25519", "work.ed25519"} {
		if !logger.IsKnownSecretRef(slug, slugs) {
			t.Fatalf("IsKnownSecretRef(%q) = false, want true", slug)
		}
	}

	for _, slug := range []string{"password", "apiKey", "token", "authToken", "foo", "host", "author", "Opencode-Go-Key", "", "nope"} {
		if logger.IsKnownSecretRef(slug, slugs) {
			t.Fatalf("IsKnownSecretRef(%q) = true, want false (exact inventory match only)", slug)
		}
	}
}
