package i3workspacegroup

import (
	"path/filepath"
	"testing"

	"go.i3wm.org/i3/v4"
)

func TestDecodeZellijTabs(t *testing.T) {
	data := []byte(`[
		{"position": 0, "tab_id": 4, "has_bell_notification": false, "is_flashing_bell": false, "active": true},
		{"position": 2, "tab_id": 7, "has_bell_notification": true, "is_flashing_bell": true, "active": false}
	]`)
	tabs, err := decodeZellijTabs(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(tabs) != 2 {
		t.Fatalf("len(tabs) = %d, want 2", len(tabs))
	}
	if tabs[1].TabID != 7 || !tabs[1].HasBell || !tabs[1].FlashingBell || tabs[1].Active {
		t.Fatalf("tabs[1] = %#v, want bell tab 7", tabs[1])
	}
}

func TestSessionForTitleUsesLongestMatch(t *testing.T) {
	sessions := []string{"magpie", "friendly-magpie", "pigeon"}
	session, ok := sessionForTitle("friendly-magpie | nvim", sessions)
	if !ok || session != "friendly-magpie" {
		t.Fatalf("sessionForTitle() = (%q, %v), want friendly-magpie", session, ok)
	}
	if _, ok := sessionForTitle("firefox", sessions); ok {
		t.Fatal("sessionForTitle(firefox) matched, want no match")
	}
}

func TestZellijWindowsMapsTitles(t *testing.T) {
	sessions := []string{"magpie", "pigeon"}
	tree := i3.Tree{Root: &i3.Node{
		Nodes: []*i3.Node{
			{ID: 1, Name: "pigeon | nvim", Window: 100},
			{ID: 2, Name: "pigeon | shell", Window: 200},
			{ID: 3, Name: "firefox", Window: 300},
			{ID: 4, Name: "container", Nodes: []*i3.Node{
				{ID: 5, Name: "magpie | logs", Window: 400},
			}},
		},
	}}

	windows := zellijWindows(tree, sessions)
	if got := windows["pigeon"]; len(got) != 2 || got[0] != 1 || got[1] != 2 {
		t.Fatalf("pigeon windows = %#v, want [1 2]", got)
	}
	if got := windows["magpie"]; len(got) != 1 || got[0] != 5 {
		t.Fatalf("magpie windows = %#v, want [5]", got)
	}
	if _, found := windows["firefox"]; found {
		t.Fatal("unexpected firefox session")
	}
}

func TestFocusedContainerID(t *testing.T) {
	tree := i3.Tree{Root: &i3.Node{
		Nodes: []*i3.Node{
			{ID: 1, Window: 100},
			{ID: 2, Window: 200, Focused: true},
		},
	}}
	if got := focusedContainerID(tree); got != 2 {
		t.Fatalf("focusedContainerID() = %d, want 2", got)
	}
}

func TestOldestTarget(t *testing.T) {
	targets := []attentionTarget{
		{Key: bellKey("pigeon", 7), WindowID: 1, Session: "pigeon", TabID: 7, Position: 1},
		{Key: bellKey("pigeon", 9), WindowID: 1, Session: "pigeon", TabID: 9, Position: 3},
		{Key: windowKey(2), WindowID: 2},
	}
	state := State{Urgent: map[string]int64{
		bellKey("pigeon", 7): 8,
		bellKey("pigeon", 9): 4,
		windowKey(2):         12,
	}}

	target, ok := oldestTarget(targets, state)
	if !ok {
		t.Fatal("oldestTarget() found nothing")
	}
	if target.Session != "pigeon" || target.TabID != 9 {
		t.Fatalf("oldestTarget() = %#v, want pigeon tab 9", target)
	}

	if _, ok := oldestTarget(targets, State{Urgent: map[string]int64{}}); ok {
		t.Fatal("oldestTarget() matched untracked targets")
	}
}

func TestUpdateUrgentPreservesFirstSeenOrder(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")

	state, err := updateUrgent(path, map[string]bool{
		bellKey("pigeon", 7): true,
		bellKey("pigeon", 9): true,
	}, false)
	if err != nil {
		t.Fatal(err)
	}
	if state.Urgent[bellKey("pigeon", 7)] != 1 || state.Urgent[bellKey("pigeon", 9)] != 2 {
		t.Fatalf("bells = %#v, want first-seen order 1, 2", state.Urgent)
	}

	state, err = updateUrgent(path, map[string]bool{
		bellKey("pigeon", 9): true,
		bellKey("magpie", 2): true,
	}, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, found := state.Urgent[bellKey("pigeon", 7)]; found {
		t.Fatalf("cleared bell still tracked: %#v", state.Urgent)
	}
	if state.Urgent[bellKey("pigeon", 9)] != 2 {
		t.Fatalf("existing bell sequence = %d, want 2", state.Urgent[bellKey("pigeon", 9)])
	}
	if state.Urgent[bellKey("magpie", 2)] != 3 {
		t.Fatalf("new bell sequence = %d, want 3", state.Urgent[bellKey("magpie", 2)])
	}
}

func TestBellKeyRoundTrip(t *testing.T) {
	key := bellKey("session:with:colons", 42)
	session, tabID, ok := parseBellKey(key)
	if !ok || session != "session:with:colons" || tabID != 42 {
		t.Fatalf("parseBellKey(%q) = (%q, %d, %v)", key, session, tabID, ok)
	}
	if _, _, ok := parseBellKey("invalid"); ok {
		t.Fatal("parseBellKey(invalid) matched")
	}
}

func TestUpdateUrgentPreservesZellijOnPartialScan(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	if _, err := updateUrgent(path, map[string]bool{
		bellKey("pigeon", 7): true,
		windowKey(2):         true,
	}, false); err != nil {
		t.Fatal(err)
	}

	state, err := updateUrgent(path, map[string]bool{
		windowKey(3): true,
	}, true)
	if err != nil {
		t.Fatal(err)
	}
	if _, found := state.Urgent[bellKey("pigeon", 7)]; !found {
		t.Fatalf("zellij bell was pruned on partial scan: %#v", state.Urgent)
	}
	if _, found := state.Urgent[windowKey(2)]; found {
		t.Fatalf("stale window was not pruned: %#v", state.Urgent)
	}
	if state.Urgent[windowKey(3)] != 3 {
		t.Fatalf("new window sequence = %d, want 3", state.Urgent[windowKey(3)])
	}
}
