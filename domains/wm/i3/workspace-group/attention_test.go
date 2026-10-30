package i3workspacegroup

import (
	"testing"

	"go.i3wm.org/i3/v4"
)

func TestWindowAttentionTargets(t *testing.T) {
	tree := i3.Tree{Root: &i3.Node{
		Nodes: []*i3.Node{
			{ID: 1, Window: 100, Urgent: true},
			{ID: 2, Window: 200},
			{ID: 3, Nodes: []*i3.Node{
				{ID: 4, Window: 300, Urgent: true},
			}},
		},
	}}

	targets := windowAttentionTargets(tree)
	if len(targets) != 2 {
		t.Fatalf("len(targets) = %d, want 2", len(targets))
	}
	if targets[0].Key != windowKey(1) || targets[0].WindowID != 1 {
		t.Fatalf("targets[0] = %#v, want window 1", targets[0])
	}
	if targets[1].Key != windowKey(4) || targets[1].WindowID != 4 {
		t.Fatalf("targets[1] = %#v, want window 4", targets[1])
	}
}

func TestTargetsForWindow(t *testing.T) {
	targets := []attentionTarget{
		{Key: windowKey(5), WindowID: 5},
		{Key: bellKey("pigeon", 7), WindowID: 5, Session: "pigeon", TabID: 7},
		{Key: bellKey("magpie", 2), WindowID: 6, Session: "magpie", TabID: 2},
	}

	filtered := targetsForWindow(targets, 5)
	if len(filtered) != 2 {
		t.Fatalf("len(filtered) = %d, want 2", len(filtered))
	}

	state := State{Urgent: map[string]int64{
		windowKey(5):         9,
		bellKey("pigeon", 7): 3,
	}}
	bell, ok := oldestZellijTarget(filtered, state)
	if !ok || bell.Session != "pigeon" || bell.TabID != 7 {
		t.Fatalf("oldestZellijTarget() = (%#v, %v), want pigeon tab 7", bell, ok)
	}
}
