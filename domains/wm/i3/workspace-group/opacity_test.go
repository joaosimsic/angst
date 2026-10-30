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
				Name:  "1",
				Focus: []i3.NodeID{20},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 20, Window: 200},
				},
			},
		},
	}

	targets := opacityTargets(root, "1")
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
				Name:  "1",
				Focus: []i3.NodeID{12, 10},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 10, Window: 100},
					{Type: i3.Con, ID: 12, Window: 120},
				},
			},
		},
	}

	targets := opacityTargets(root, "1")
	if !targets[120] {
		t.Fatalf("focused window = %#v, want focused", targets)
	}
	if targets[100] {
		t.Fatalf("unfocused window = %#v, want dimmed", targets)
	}
}

func TestOpacityTargetsKeepsStickyWindowsFocused(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Name:  "1",
				Focus: []i3.NodeID{12},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 12, Window: 120},
				},
				FloatingNodes: []*i3.Node{
					{
						Type: i3.FloatingCon,
						ID:   11,
						Nodes: []*i3.Node{
							{Type: i3.Con, ID: 11, Window: 110, Sticky: true},
						},
					},
				},
			},
		},
	}

	targets := opacityTargets(root, "1")
	if !targets[110] {
		t.Fatalf("sticky window = %#v, want full opacity", targets)
	}
	if !targets[120] {
		t.Fatalf("focused window = %#v, want focused", targets)
	}
}

func TestOpacityTargetsKeepsFloatingWindowsFocused(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Name:  "1",
				Focus: []i3.NodeID{20},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 20, Window: 200},
				},
				FloatingNodes: []*i3.Node{
					{
						Type: i3.FloatingCon,
						ID:   30,
						Nodes: []*i3.Node{
							{Type: i3.Con, ID: 31, Window: 310},
						},
					},
				},
			},
		},
	}

	targets := opacityTargets(root, "1")
	if !targets[200] {
		t.Fatalf("focused window = %#v, want focused", targets)
	}
	if !targets[310] {
		t.Fatalf("floating window = %#v, want full opacity", targets)
	}
}

func TestOpacityTargetsNestedFocus(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Name:  "1",
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

	targets := opacityTargets(root, "1")
	if !targets[310] {
		t.Fatalf("nested focused window = %#v, want focused", targets)
	}
	if targets[320] {
		t.Fatalf("nested unfocused window = %#v, want dimmed", targets)
	}
}

func TestOpacityTargetsOnlyDimsActiveWorkspace(t *testing.T) {
	root := &i3.Node{
		Type: i3.Root,
		Nodes: []*i3.Node{
			{
				Type:  i3.WorkspaceNode,
				Name:  "1",
				Focus: []i3.NodeID{12, 10},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 10, Window: 100},
					{Type: i3.Con, ID: 12, Window: 120},
				},
			},
			{
				Type:  i3.WorkspaceNode,
				Name:  "2",
				Focus: []i3.NodeID{22, 20},
				Nodes: []*i3.Node{
					{Type: i3.Con, ID: 20, Window: 200},
					{Type: i3.Con, ID: 22, Window: 220},
				},
			},
		},
	}

	targets := opacityTargets(root, "1")
	if !targets[120] || targets[100] {
		t.Fatalf("active workspace targets = %#v, want 120 focused and 100 dimmed", targets)
	}
	if !targets[200] || !targets[220] {
		t.Fatalf("inactive workspace targets = %#v, want all windows full opacity", targets)
	}

	targets = opacityTargets(root, "2")
	if !targets[220] || targets[200] {
		t.Fatalf("active secondary workspace targets = %#v, want 220 focused and 200 dimmed", targets)
	}
	if !targets[100] || !targets[120] {
		t.Fatalf("inactive primary workspace targets = %#v, want all windows full opacity", targets)
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
