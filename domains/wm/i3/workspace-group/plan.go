package i3workspacegroup

import (
	"fmt"
	"sort"
	"strconv"

	"go.i3wm.org/i3/v4"
)

type SwitchPlan struct {
	Commands       []string
	OriginalOutput string
}

type RenamePlan struct {
	Old string
	New string
}

func activeOutputs(outputs []i3.Output) []i3.Output {
	active := make([]i3.Output, 0, len(outputs))
	for _, output := range outputs {
		if output.Active {
			active = append(active, output)
		}
	}
	return active
}

func focusedWorkspace(workspaces []i3.Workspace) (i3.Workspace, bool) {
	for _, workspace := range workspaces {
		if workspace.Focused {
			return workspace, true
		}
	}
	return i3.Workspace{}, false
}

func visibleWorkspaceForOutput(workspaces []i3.Workspace, output string) (i3.Workspace, bool) {
	for _, workspace := range workspaces {
		if workspace.Visible && workspace.Output == output {
			return workspace, true
		}
	}
	return i3.Workspace{}, false
}

func parseFocusedWorkspace(workspaces []i3.Workspace) (group, inner int, output string, ok bool) {
	focused, found := focusedWorkspace(workspaces)
	if !found {
		return 0, 0, "", false
	}
	return ParseWorkspace(focused.Name)
}

func PlanSwitch(outputs []i3.Output, workspaces []i3.Workspace, state State, group int) SwitchPlan {
	plan := SwitchPlan{}
	if focused, ok := focusedWorkspace(workspaces); ok {
		plan.OriginalOutput = focused.Output
	}

	for _, output := range activeOutputs(outputs) {
		inner := state.LastInner(group, output.Name, 1)
		plan.Commands = append(
			plan.Commands,
			FocusOutputCommand(output.Name),
			SwitchWorkspaceCommand(WorkspaceName(group, inner, output.Name)),
		)
	}
	if len(plan.Commands) > 0 && plan.OriginalOutput != "" {
		plan.Commands = append(plan.Commands, FocusOutputCommand(plan.OriginalOutput))
	}
	return plan
}

func PlanMoveTop(workspaces []i3.Workspace, state State, group int) (string, error) {
	focused, ok := focusedWorkspace(workspaces)
	if !ok {
		return "", fmt.Errorf("no focused workspace")
	}
	inner := state.LastInner(group, focused.Output, 1)
	return MoveWindowToWorkspaceCommand(WorkspaceName(group, inner, focused.Output)), nil
}

func PlanInnerSwitch(workspaces []i3.Workspace, inner int) (string, int, string, error) {
	group, _, output, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return "", 0, "", fmt.Errorf("focused workspace is not part of a workspace group")
	}
	return SwitchWorkspaceCommand(WorkspaceName(group, inner, output)), group, output, nil
}

func PlanInnerMove(workspaces []i3.Workspace, inner int) (string, error) {
	group, _, output, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return "", fmt.Errorf("focused workspace is not part of a workspace group")
	}
	return MoveWindowToWorkspaceCommand(WorkspaceName(group, inner, output)), nil
}

func PlanAdopt(workspaces []i3.Workspace) []RenamePlan {
	existing := make(map[string]bool, len(workspaces))
	for _, workspace := range workspaces {
		existing[workspace.Name] = true
	}

	planned := make([]RenamePlan, 0, len(workspaces))
	seenTargets := make(map[string]bool)
	for _, workspace := range workspaces {
		if _, _, _, nested := ParseWorkspace(workspace.Name); nested {
			continue
		}

		inner := 0
		if legacyGroup, _, legacy := ParseLegacyWorkspace(workspace.Name); legacy {
			inner = legacyGroup
		} else if plain, plainOk := ParsePlainWorkspace(workspace.Name, workspace.Num); plainOk {
			inner = plain
		} else {
			continue
		}

		target := WorkspaceName(1, inner, workspace.Output)
		if existing[target] || seenTargets[target] || workspace.Name == target {
			continue
		}
		planned = append(planned, RenamePlan{Old: workspace.Name, New: target})
		seenTargets[target] = true
	}
	return planned
}

func PlanBarState(outputs []i3.Output, workspaces []i3.Workspace) []i3.Workspace {
	state := make([]i3.Workspace, 0)
	for _, output := range activeOutputs(outputs) {
		visible, ok := visibleWorkspaceForOutput(workspaces, output.Name)
		if !ok {
			continue
		}
		group, _, _, grouped := ParseWorkspace(visible.Name)
		if !grouped {
			state = append(state, i3.Workspace{
				ID:     visible.ID,
				Num:    -1,
				Name:   "1",
				Output: output.Name,
			})
			for _, workspace := range workspaces {
				if workspace.Output == output.Name {
					workspace.Visible = true
					state = append(state, workspace)
				}
			}
			continue
		}

		state = append(state, i3.Workspace{
			ID:     visible.ID,
			Num:    -1,
			Name:   strconv.Itoa(group),
			Output: output.Name,
		})

		inners := make([]i3.Workspace, 0)
		for _, workspace := range workspaces {
			workspaceGroup, inner, workspaceOutput, nested := ParseWorkspace(workspace.Name)
			if !nested || workspaceGroup != group || workspaceOutput != output.Name {
				continue
			}
			workspace.Name = strconv.Itoa(inner)
			workspace.Num = int64(inner)
			workspace.Visible = true
			inners = append(inners, workspace)
		}
		sort.Slice(inners, func(first, second int) bool {
			return inners[first].Num < inners[second].Num
		})
		state = append(state, inners...)
	}
	return state
}

func PlanSync(outputs []i3.Output, workspaces []i3.Workspace, state State, group int) []string {
	active := activeOutputs(outputs)
	if len(active) == 0 {
		return nil
	}

	originalOutput := ""
	if focused, ok := focusedWorkspace(workspaces); ok {
		originalOutput = focused.Output
	}

	commands := make([]string, 0, len(active)*2+1)
	for _, output := range active {
		visible, ok := visibleWorkspaceForOutput(workspaces, output.Name)
		if ok {
			currentGroup, _, _, grouped := ParseWorkspace(visible.Name)
			if grouped && currentGroup == group {
				continue
			}
		}
		inner := state.LastInner(group, output.Name, 1)
		commands = append(
			commands,
			FocusOutputCommand(output.Name),
			SwitchWorkspaceCommand(WorkspaceName(group, inner, output.Name)),
		)
	}
	if len(commands) > 0 && originalOutput != "" {
		commands = append(commands, FocusOutputCommand(originalOutput))
	}
	return commands
}

func PlanRepair(workspaces []i3.Workspace) []string {
	for _, workspace := range workspaces {
		if !workspace.Focused {
			continue
		}
		_, _, suffix, ok := ParseWorkspace(workspace.Name)
		if !ok || suffix == workspace.Output {
			return nil
		}
		return []string{MoveWorkspaceToOutputCommand(suffix)}
	}
	return nil
}

func PlanInnerSwap(tree i3.Tree, workspaces []i3.Workspace, first, second int) ([]string, error) {
	group, _, output, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return nil, fmt.Errorf("focused workspace is not part of a workspace group")
	}
	return planSwapNames(
		tree,
		WorkspaceName(group, first, output),
		WorkspaceName(group, second, output),
	)
}

func planSwapNames(tree i3.Tree, firstName, secondName string) ([]string, error) {
	firstWorkspace := findWorkspace(tree.Root, firstName)
	secondWorkspace := findWorkspace(tree.Root, secondName)
	if firstWorkspace == nil {
		return nil, fmt.Errorf("workspace %q not found", firstName)
	}
	if secondWorkspace == nil {
		return nil, fmt.Errorf("workspace %q not found", secondName)
	}

	firstTiling := nodeIDs(firstWorkspace.Nodes)
	secondTiling := nodeIDs(secondWorkspace.Nodes)
	commands := make([]string, 0, len(firstTiling)+len(secondTiling))

	paired := minInt(len(firstTiling), len(secondTiling))
	for index := 0; index < paired; index++ {
		commands = append(commands, SwapContainersCommand(firstTiling[index], secondTiling[index]))
	}
	for _, id := range firstTiling[paired:] {
		commands = append(commands, MoveContainerToWorkspaceCommand(id, secondName))
	}
	for _, id := range secondTiling[paired:] {
		commands = append(commands, MoveContainerToWorkspaceCommand(id, firstName))
	}
	for _, id := range nodeIDs(firstWorkspace.FloatingNodes) {
		commands = append(commands, MoveContainerToWorkspaceCommand(id, secondName))
	}
	for _, id := range nodeIDs(secondWorkspace.FloatingNodes) {
		commands = append(commands, MoveContainerToWorkspaceCommand(id, firstName))
	}
	return commands, nil
}

func findWorkspace(root *i3.Node, name string) *i3.Node {
	if root == nil {
		return nil
	}
	return root.FindChild(func(node *i3.Node) bool {
		return node.Type == i3.WorkspaceNode && node.Name == name
	})
}

func nodeIDs(nodes []*i3.Node) []i3.NodeID {
	ids := make([]i3.NodeID, 0, len(nodes))
	for _, node := range nodes {
		ids = append(ids, node.ID)
	}
	return ids
}

func minInt(first, second int) int {
	if first < second {
		return first
	}
	return second
}
