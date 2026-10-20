package i3workspacegroup

import (
	"reflect"
	"testing"

	"go.i3wm.org/i3/v4"
)

func testOutputs() []i3.Output {
	return []i3.Output{
		{Name: "DP-1", Active: true},
		{Name: "HDMI-2", Active: true},
		{Name: "xroot-0", Active: false},
	}
}

func testWorkspaces() []i3.Workspace {
	return []i3.Workspace{
		{ID: 1, Name: "1:1", Num: 1, Output: "DP-1", Visible: true, Focused: true},
		{ID: 2, Name: "1:2", Num: 2, Output: "HDMI-2", Visible: true},
		{ID: 3, Name: "1:4", Num: 4, Output: "HDMI-2"},
		{ID: 4, Name: "1:5", Num: 5, Output: "HDMI-2"},
		{ID: 5, Name: "2:3", Num: 3, Output: "DP-1"},
		{ID: 6, Name: "2:1", Num: 1, Output: "HDMI-2"},
	}
}

func testState() State {
	return State{Last: map[string]map[string]int{
		"1": {"DP-1": 1, "HDMI-2": 2},
		"2": {"DP-1": 3, "HDMI-2": 1},
	}}
}

func TestPlanSwitch(t *testing.T) {
	plan := PlanSwitch(testOutputs(), testWorkspaces(), testState(), 2)
	want := []string{
		`focus output "DP-1"`,
		`workspace --no-auto-back-and-forth "2:3"`,
		`focus output "HDMI-2"`,
		`workspace --no-auto-back-and-forth "2:1"`,
		`focus output "DP-1"`,
	}
	if !reflect.DeepEqual(plan.Commands, want) {
		t.Fatalf("PlanSwitch commands = %#v, want %#v", plan.Commands, want)
	}
	if plan.OriginalOutput != "DP-1" {
		t.Fatalf("PlanSwitch original output = %q, want DP-1", plan.OriginalOutput)
	}
}

func TestPlanSwitchCreatesFreeInnerOnEveryOutput(t *testing.T) {
	plan := PlanSwitch(testOutputs(), testWorkspaces(), newState(), 3)
	want := []string{
		`focus output "DP-1"`,
		`workspace --no-auto-back-and-forth "3:1"`,
		`focus output "HDMI-2"`,
		`workspace --no-auto-back-and-forth "3:2"`,
		`focus output "DP-1"`,
	}
	if !reflect.DeepEqual(plan.Commands, want) {
		t.Fatalf("PlanSwitch commands = %#v, want %#v", plan.Commands, want)
	}
}

func TestPlanMoveTop(t *testing.T) {
	command, err := PlanMoveTop(testWorkspaces(), testState(), 2)
	if err != nil {
		t.Fatal(err)
	}
	if want := `move container to workspace "2:3"`; command != want {
		t.Fatalf("PlanMoveTop() = %q, want %q", command, want)
	}
}

func TestPlanMoveTopNoFocus(t *testing.T) {
	if _, err := PlanMoveTop(nil, testState(), 1); err == nil {
		t.Fatal("PlanMoveTop() error = nil, want error")
	}
}

func TestPlanInnerSwitchJumpsToOtherMonitor(t *testing.T) {
	command, group, output, err := PlanInnerSwitch(testWorkspaces(), 2)
	if err != nil {
		t.Fatal(err)
	}
	if want := `workspace --no-auto-back-and-forth "1:2"`; command != want {
		t.Fatalf("PlanInnerSwitch() = %q, want %q", command, want)
	}
	if group != 1 || output != "HDMI-2" {
		t.Fatalf("PlanInnerSwitch() = (%d, %q), want (1, HDMI-2)", group, output)
	}
}

func TestPlanInnerSwitchCreatesOnCurrentMonitor(t *testing.T) {
	command, group, output, err := PlanInnerSwitch(testWorkspaces(), 3)
	if err != nil {
		t.Fatal(err)
	}
	if want := `workspace --no-auto-back-and-forth "1:3"`; command != want {
		t.Fatalf("PlanInnerSwitch() = %q, want %q", command, want)
	}
	if group != 1 || output != "DP-1" {
		t.Fatalf("PlanInnerSwitch() = (%d, %q), want (1, DP-1)", group, output)
	}
}

func TestPlanInnerMoveFollowsWorkspace(t *testing.T) {
	command, err := PlanInnerMove(testWorkspaces(), 2)
	if err != nil {
		t.Fatal(err)
	}
	if want := `move container to workspace "1:2"`; command != want {
		t.Fatalf("PlanInnerMove() = %q, want %q", command, want)
	}
}

func TestPlanAdopt(t *testing.T) {
	workspaces := []i3.Workspace{
		{Name: "1:1", Num: 1, Output: "DP-1"},
		{Name: "1:1:HDMI-2", Num: 1, Output: "HDMI-2"},
		{Name: "1:3:DP-1", Num: 3, Output: "DP-1"},
		{Name: "2:4:HDMI-2", Num: 4, Output: "HDMI-2"},
		{Name: "1:5:DP-1", Num: 5, Output: "DP-1"},
		{Name: "notes", Num: -1, Output: "DP-1"},
	}
	want := []RenamePlan{
		{Old: "1:1:HDMI-2", New: "1:2"},
		{Old: "1:3:DP-1", New: "1:3"},
		{Old: "2:4:HDMI-2", New: "2:4"},
		{Old: "1:5:DP-1", New: "1:5"},
	}
	if got := PlanAdopt(workspaces); !reflect.DeepEqual(got, want) {
		t.Fatalf("PlanAdopt() = %#v, want %#v", got, want)
	}
}

func TestPlanBarState(t *testing.T) {
	state := PlanBarState(testOutputs(), testWorkspaces())
	if len(state) != 6 {
		t.Fatalf("PlanBarState len = %d, want 6", len(state))
	}
	if state[0].ID != 1 || state[0].Name != "1" || state[0].Output != "DP-1" || state[0].Visible {
		t.Fatalf("state[0] = %#v, want DP-1 group label", state[0])
	}
	if state[1].ID != 1 || state[1].Name != "1" || state[1].Output != "DP-1" || !state[1].Visible {
		t.Fatalf("state[1] = %#v, want DP-1 inner 1", state[1])
	}
	if state[2].ID != 2 || state[2].Name != "1" || state[2].Output != "HDMI-2" || state[2].Visible {
		t.Fatalf("state[2] = %#v, want HDMI-2 group label", state[2])
	}
	if state[3].ID != 2 || state[3].Name != "2" || state[3].Output != "HDMI-2" || !state[3].Visible {
		t.Fatalf("state[3] = %#v, want HDMI-2 inner 2", state[3])
	}
	if state[4].ID != 3 || state[4].Name != "4" || state[4].Output != "HDMI-2" || !state[4].Visible {
		t.Fatalf("state[4] = %#v, want HDMI-2 inner 4", state[4])
	}
	if state[5].ID != 4 || state[5].Name != "5" || state[5].Output != "HDMI-2" || !state[5].Visible {
		t.Fatalf("state[5] = %#v, want HDMI-2 inner 5", state[5])
	}
}

func TestPlanBarStateLegacyFallback(t *testing.T) {
	state := PlanBarState(testOutputs(), []i3.Workspace{
		{ID: 7, Name: "1", Num: 1, Output: "DP-1", Visible: true, Focused: true},
		{ID: 8, Name: "2", Num: 2, Output: "HDMI-2", Visible: true},
	})
	if len(state) != 4 {
		t.Fatalf("PlanBarState len = %d, want 4", len(state))
	}
	if state[0].ID != 7 || state[0].Name != "1" || state[0].Visible {
		t.Fatalf("state[0] = %#v, want fallback group label", state[0])
	}
	if state[1].ID != 7 || state[1].Name != "1" || !state[1].Visible {
		t.Fatalf("state[1] = %#v, want legacy DP-1 workspace", state[1])
	}
	if state[2].ID != 8 || state[2].Name != "1" || state[2].Visible {
		t.Fatalf("state[2] = %#v, want fallback HDMI-2 group label", state[2])
	}
	if state[3].ID != 8 || state[3].Name != "2" || !state[3].Visible {
		t.Fatalf("state[3] = %#v, want legacy HDMI-2 workspace", state[3])
	}
}

func TestPlanSync(t *testing.T) {
	workspaces := testWorkspaces()
	workspaces[2].Name = "1:4"
	commands := PlanSync(testOutputs(), workspaces, testState(), 2)
	want := []string{
		`focus output "DP-1"`,
		`workspace --no-auto-back-and-forth "2:3"`,
		`focus output "HDMI-2"`,
		`workspace --no-auto-back-and-forth "2:1"`,
		`focus output "DP-1"`,
	}
	if !reflect.DeepEqual(commands, want) {
		t.Fatalf("PlanSync() = %#v, want %#v", commands, want)
	}
}

func TestPlanSyncPreservesInnerOnOtherMonitor(t *testing.T) {
	workspaces := testWorkspaces()
	workspaces[0].Name = "2:3"
	commands := PlanSync(testOutputs(), workspaces, testState(), 2)
	want := []string{
		`focus output "HDMI-2"`,
		`workspace --no-auto-back-and-forth "2:1"`,
		`focus output "DP-1"`,
	}
	if !reflect.DeepEqual(commands, want) {
		t.Fatalf("PlanSync() = %#v, want %#v", commands, want)
	}
}

func TestPlanInnerSwap(t *testing.T) {
	tree := i3.Tree{Root: &i3.Node{
		Nodes: []*i3.Node{{
			Type: i3.OutputNode,
			Nodes: []*i3.Node{
				{
					Type:          i3.WorkspaceNode,
					Name:          "1:1",
					Nodes:         []*i3.Node{{ID: 1}, {ID: 2}},
					FloatingNodes: []*i3.Node{{ID: 5}},
				},
				{
					Type:  i3.WorkspaceNode,
					Name:  "1:2",
					Nodes: []*i3.Node{{ID: 3}},
				},
			},
		}},
	}}

	commands, err := PlanInnerSwap(tree, testWorkspaces(), 1, 2)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"[con_id=1] swap container with con_id 3",
		`[con_id=2] move container to workspace "1:2"`,
		`[con_id=5] move container to workspace "1:2"`,
	}
	if !reflect.DeepEqual(commands, want) {
		t.Fatalf("PlanInnerSwap() = %#v, want %#v", commands, want)
	}
}

func TestPlanInnerSwapMissingWorkspace(t *testing.T) {
	tree := i3.Tree{Root: &i3.Node{}}
	if _, err := PlanInnerSwap(tree, testWorkspaces(), 1, 2); err == nil {
		t.Fatal("PlanInnerSwap() error = nil, want error")
	}
}
