package i3workspacegroup

import (
	"reflect"
	"testing"

	"go.i3wm.org/i3/v4"
)

func stickyFloatingNode(id i3.NodeID, sticky bool) *i3.Node {
	return &i3.Node{
		Type: i3.FloatingCon,
		Nodes: []*i3.Node{{
			Type:   i3.Con,
			ID:     id,
			Window: int64(id),
			Sticky: sticky,
		}},
	}
}

func stickyWorkspace(name string, floating ...*i3.Node) *i3.Node {
	return &i3.Node{
		Type:          i3.WorkspaceNode,
		Name:          name,
		FloatingNodes: floating,
	}
}

func stickyTree(windowOutput string, window i3.NodeID, sticky bool) *i3.Node {
	outputs := []*i3.Node{
		{Type: i3.OutputNode, Name: "DP-1", Nodes: []*i3.Node{stickyWorkspace("1:1")}},
		{Type: i3.OutputNode, Name: "HDMI-2", Nodes: []*i3.Node{stickyWorkspace("2:1")}},
	}
	for _, output := range outputs {
		if output.Name != windowOutput {
			continue
		}
		output.Nodes[0].FloatingNodes = []*i3.Node{stickyFloatingNode(window, sticky)}
	}
	return &i3.Node{Type: i3.Root, Nodes: outputs}
}

func stickyWorkspaces() []i3.Workspace {
	return []i3.Workspace{
		{Name: "1:1", Output: "DP-1", Visible: true},
		{Name: "2:1", Output: "HDMI-2", Visible: true},
	}
}

func TestFloatingWindowsTracksOutputAndSkipsInternalWorkspaces(t *testing.T) {
	tree := stickyTree("DP-1", 5, true)
	tree.Nodes = append(tree.Nodes, &i3.Node{
		Type: i3.OutputNode,
		Name: "__i3",
		Nodes: []*i3.Node{{
			Type:          i3.WorkspaceNode,
			Name:          "__i3_scratch",
			FloatingNodes: []*i3.Node{stickyFloatingNode(9, true)},
		}},
	})
	tree.Nodes[0].Nodes[0].Nodes = []*i3.Node{{Type: i3.Con, ID: 7, Window: 107, Sticky: true}}

	windows := floatingWindows(tree)
	want := []floatingWindow{{id: 5, output: "DP-1", sticky: true}}
	if !reflect.DeepEqual(windows, want) {
		t.Fatalf("floatingWindows() = %#v, want %#v", windows, want)
	}
}

func TestPlanStickyPinsRestoresOriginalOutput(t *testing.T) {
	tree := stickyTree("HDMI-2", 5, true)
	pins := map[i3.NodeID]string{5: "DP-1"}

	commands := planStickyPins(tree, stickyWorkspaces(), pins)
	want := []string{`[con_id=5] move container to workspace "1:1"`}
	if !reflect.DeepEqual(commands, want) {
		t.Fatalf("planStickyPins() = %#v, want %#v", commands, want)
	}
	if pins[5] != "DP-1" {
		t.Fatalf("pin = %q, want DP-1", pins[5])
	}
}

func TestPlanStickyPinsRecordsCurrentOutput(t *testing.T) {
	tree := stickyTree("DP-1", 5, true)
	pins := make(map[i3.NodeID]string)

	commands := planStickyPins(tree, stickyWorkspaces(), pins)
	if len(commands) != 0 {
		t.Fatalf("planStickyPins() = %#v, want no commands", commands)
	}
	if pins[5] != "DP-1" {
		t.Fatalf("pin = %q, want DP-1", pins[5])
	}
}

func TestPlanStickyPinsKeepsWindowsOnSameOutput(t *testing.T) {
	tree := stickyTree("DP-1", 5, true)
	pins := map[i3.NodeID]string{5: "DP-1"}

	commands := planStickyPins(tree, stickyWorkspaces(), pins)
	if len(commands) != 0 {
		t.Fatalf("planStickyPins() = %#v, want no commands", commands)
	}
}

func TestPlanStickyPinsDropsMissingOutput(t *testing.T) {
	tree := stickyTree("DP-1", 5, true)
	pins := map[i3.NodeID]string{5: "DISCONNECTED"}

	commands := planStickyPins(tree, stickyWorkspaces(), pins)
	if len(commands) != 0 {
		t.Fatalf("planStickyPins() = %#v, want no commands", commands)
	}
	if pins[5] != "DP-1" {
		t.Fatalf("pin = %q, want DP-1", pins[5])
	}
}

func TestPlanStickyPinsCleansStaleWindows(t *testing.T) {
	tree := stickyTree("DP-1", 5, true)
	pins := map[i3.NodeID]string{5: "DP-1", 9: "DP-1"}

	commands := planStickyPins(tree, stickyWorkspaces(), pins)
	if len(commands) != 0 {
		t.Fatalf("planStickyPins() = %#v, want no commands", commands)
	}
	if _, found := pins[9]; found {
		t.Fatalf("stale pin 9 was not removed: %#v", pins)
	}
}
