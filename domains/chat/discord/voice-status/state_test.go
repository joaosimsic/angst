package main

import (
	"os"
	"strings"
	"testing"
	"time"
)

func freshSnapshot() snapshot {
	return snapshot{
		PID:       os.Getpid(),
		UpdatedAt: time.Now().UnixMilli(),
		Discord:   true,
		InChannel: true,
		Connected: true,
		Channel:   "General",
	}
}

func TestPanelUnmuted(t *testing.T) {
	panel := panelFromSnapshot(freshSnapshot(), time.Now())
	if panel.State != "Good" {
		t.Fatalf("state = %q, want Good", panel.State)
	}
	if panel.Icon != "microphone" {
		t.Fatalf("icon = %q, want microphone", panel.Icon)
	}
	if panel.Text != "General" {
		t.Fatalf("text = %q, want General", panel.Text)
	}
}

func TestPanelMuted(t *testing.T) {
	snap := freshSnapshot()
	snap.Mute = true
	panel := panelFromSnapshot(snap, time.Now())
	if panel.State != "Warning" {
		t.Fatalf("state = %q, want Warning", panel.State)
	}
	if panel.Icon != "microphone_muted" {
		t.Fatalf("icon = %q, want microphone_muted", panel.Icon)
	}
}

func TestPanelDeafenedWins(t *testing.T) {
	snap := freshSnapshot()
	snap.Mute = true
	snap.Deaf = true
	panel := panelFromSnapshot(snap, time.Now())
	if panel.State != "Critical" {
		t.Fatalf("state = %q, want Critical", panel.State)
	}
	if panel.Icon != "volume_muted" {
		t.Fatalf("icon = %q, want volume_muted", panel.Icon)
	}
	if !strings.HasSuffix(panel.Text, " deaf") {
		t.Fatalf("text = %q, want deaf suffix", panel.Text)
	}
}

func TestPanelHiddenOutsideVoice(t *testing.T) {
	snap := freshSnapshot()
	snap.InChannel = false
	panel := panelFromSnapshot(snap, time.Now())
	if panel != hiddenPanel {
		t.Fatalf("panel = %#v, want hidden", panel)
	}
}

func TestPanelHiddenWhenDisconnected(t *testing.T) {
	snap := freshSnapshot()
	snap.Connected = false
	panel := panelFromSnapshot(snap, time.Now())
	if panel != hiddenPanel {
		t.Fatalf("panel = %#v, want hidden", panel)
	}
}

func TestPanelHiddenWhenStale(t *testing.T) {
	snap := freshSnapshot()
	snap.UpdatedAt = time.Now().Add(-panelFreshness - time.Second).UnixMilli()
	panel := panelFromSnapshot(snap, time.Now())
	if panel != hiddenPanel {
		t.Fatalf("panel = %#v, want hidden", panel)
	}
}

func TestPanelAuthPending(t *testing.T) {
	snap := freshSnapshot()
	snap.AuthPending = true
	panel := panelFromSnapshot(snap, time.Now())
	if panel.State != "Warning" || panel.Text != "discord auth" {
		t.Fatalf("panel = %#v", panel)
	}
}

func TestSanitizeChannel(t *testing.T) {
	long := strings.Repeat("a", channelLimit+5)
	result := sanitizeChannel(long)
	if len(result) != channelLimit+3 {
		t.Fatalf("length = %d, want %d", len(result), channelLimit+3)
	}
	if !strings.HasSuffix(result, "...") {
		t.Fatalf("result = %q, want ellipsis", result)
	}
	if got := sanitizeChannel("  "); got != "voice" {
		t.Fatalf("empty channel = %q, want voice", got)
	}
	if got := sanitizeChannel("Gene\nral"); got != "General" {
		t.Fatalf("control channel = %q, want General", got)
	}
}

func TestTokenCachePermissions(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	if err := saveToken("secret-token"); err != nil {
		t.Fatalf("saveToken: %v", err)
	}
	path, err := tokenPath()
	if err != nil {
		t.Fatalf("tokenPath: %v", err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat token: %v", err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o, want 600", info.Mode().Perm())
	}
	token, err := loadToken()
	if err != nil {
		t.Fatalf("loadToken: %v", err)
	}
	if token != "secret-token" {
		t.Fatalf("token = %q", token)
	}
	if err := clearToken(); err != nil {
		t.Fatalf("clearToken: %v", err)
	}
	token, err = loadToken()
	if err != nil {
		t.Fatalf("loadToken after clear: %v", err)
	}
	if token != "" {
		t.Fatalf("token after clear = %q", token)
	}
}
