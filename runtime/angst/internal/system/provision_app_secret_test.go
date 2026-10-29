package system

import "testing"

func TestSplitScopedSlug(t *testing.T) {
	sc, name, scoped, err := splitScopedSlug("personal/opencode-go-key")
	if err != nil {
		t.Fatalf("splitScopedSlug: %v", err)
	}
	if !scoped || string(sc) != "personal" || name != "opencode-go-key" {
		t.Fatalf("got scope=%q name=%q scoped=%v", sc, name, scoped)
	}

	sc, name, scoped, err = splitScopedSlug("opencode-go-key")
	if err != nil {
		t.Fatalf("legacy splitScopedSlug: %v", err)
	}
	if scoped || name != "opencode-go-key" {
		t.Fatalf("legacy got scope=%q name=%q scoped=%v", sc, name, scoped)
	}

	for _, raw := range []string{"other/key", "personal/", "personal/a/b", "personal/.."} {
		if _, _, _, err := splitScopedSlug(raw); err == nil {
			t.Fatalf("expected error for %q", raw)
		}
	}
}
