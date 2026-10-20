package i3workspacegroup

import (
	"testing"

	"go.i3wm.org/i3/v4"
)

func TestOpacityTargetsSingleWindowWorkspace(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Focus: []i3.NodeID{20},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 20, Window: 200},
				},
			},
		},
	}

	targets := opacityTargets(root)
	if !targets[200] {
		t.Fatalf("single workspace window = %#v, want focused", targets)
	}
}

func TestOpacityTargetsDimsUnfocusedWorkspaceWindows(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Focus: []i3.NodeID{12, 10},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 10, Window: 100},
					{Type: i3.Con, ID: 12, Window: 120},
				},
			},
		},
	}

	targets := opacityTargets(root)
	if !targets[120] {
		t.Fatalf("focused window = %#v, want focused", targets)
	}
	if targets[100] {
		t.Fatalf("unfocused window = %#v, want dimmed", targets)
	}
}

func TestOpacityTargetsNestedFocus(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Focus: []i3.NodeID{30},
				Nodes: []*i3.Node{
					{
						Type:  i3.Con,
						ID:    30,
						Focus: []i3.NodeID{31},
						Nodes: []*i3.Node{
							{Type: i3.Con, ID: 31, Window: 310},
							{Type: i3.Con, ID: 32, Window: 320},
						},
					},
				},
			},
		},
	}

	targets := opacityTargets(root)
	if !targets[310] {
		t.Fatalf("nested focused window = %#v, want focused", targets)
	}
	if targets[320] {
		t.Fatalf("nested unfocused window = %#v, want dimmed", targets)
	}
}

func TestOpacityTargetsPerWorkspace(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Focus: []i3.NodeID{12, 10},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 10, Window: 100},
					{Type: i3.Con, ID: 12, Window: 120},
				},
			},
			{
				Type:  i3.WorkspaceNode,
				Focus: []i3.NodeID{20},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 20, Window: 200},
				},
			},
		},
	}

	targets := opacityTargets(root)
	if !targets[120] || !targets[200] {
		t.Fatalf("workspace focus targets = %#v, want both focused", targets)
	}
	if targets[100] {
		t.Fatalf("workspace focus targets = %#v, want 100 dimmed", targets)
	}
}

func TestInactiveOpacity(t *testing.T) {
	t.Setenv("ANGST_INACTIVE_OPACITY", "")
	if got := inactiveOpacity(); got != defaultInactiveOpacity {
		t.Fatalf("default inactive opacity = %d, want %d", got, defaultInactiveOpacity)
	}

	t.Setenv("ANGST_INACTIVE_OPACITY", "82")
	if got := inactiveOpacity(); got != 82 {
		t.Fatalf("configured inactive opacity = %d, want 82", got)
	}

	t.Setenv("ANGST_INACTIVE_OPACITY", "5")
	if got := inactiveOpacity(); got != defaultInactiveOpacity {
		t.Fatalf("invalid inactive opacity = %d, want %d", got, defaultInactiveOpacity)
	}
}
