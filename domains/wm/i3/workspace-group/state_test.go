package i3workspacegroup

import (
	"os"
	"path/filepath"
	"testing"
)

func TestUpdateAndLoadState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	if err := updateState(path, 2, "DP-1", 3); err != nil {
		t.Fatal(err)
	}
	if err := updateState(path, 2, "HDMI-2", 4); err != nil {
		t.Fatal(err)
	}

	state, err := loadState(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := state.LastInner(2, "DP-1", 1); got != 3 {
		t.Fatalf("LastInner(2, DP-1) = %d, want 3", got)
	}
	if got := state.LastInner(2, "HDMI-2", 1); got != 4 {
		t.Fatalf("LastInner(2, HDMI-2) = %d, want 4", got)
	}
	if got := state.LastInner(9, "DP-1", 1); got != 1 {
		t.Fatalf("LastInner fallback = %d, want 1", got)
	}
}

func TestSeedState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	if err := seedState(path, map[int]map[string]int{
		1: {"DP-1": 1, "HDMI-2": 2},
	}); err != nil {
		t.Fatal(err)
	}
	state, err := loadState(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := state.LastInner(1, "DP-1", 9); got != 1 {
		t.Fatalf("LastInner(1, DP-1) = %d, want 1", got)
	}
	if got := state.LastInner(1, "HDMI-2", 9); got != 2 {
		t.Fatalf("LastInner(1, HDMI-2) = %d, want 2", got)
	}
}

func TestUpdateStateReplacesCorruptState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	if err := os.WriteFile(path, []byte("{not json"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := updateState(path, 1, "DP-1", 2); err != nil {
		t.Fatal(err)
	}
	state, err := loadState(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := state.LastInner(1, "DP-1", 1); got != 2 {
		t.Fatalf("LastInner(1, DP-1) = %d, want 2", got)
	}
}

func TestStatePathUsesRuntimeDir(t *testing.T) {
	directory := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", directory)
	path := statePath()
	if filepath.Dir(path) != directory {
		t.Fatalf("statePath() directory = %q, want %q", filepath.Dir(path), directory)
	}
}
