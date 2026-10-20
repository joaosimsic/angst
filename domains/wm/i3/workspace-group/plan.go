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

type innerSelection struct {
	inner    int
	moveFrom string
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
	group, inner, ok = ParseWorkspace(focused.Name)
	if !ok {
		return 0, 0, "", false
	}
	return group, inner, focused.Output, true
}

func existingGroupWorkspaces(workspaces []i3.Workspace, group int) map[int]i3.Workspace {
	existing := make(map[int]i3.Workspace)
	for _, workspace := range workspaces {
		workspaceGroup, inner, ok := ParseWorkspace(workspace.Name)
		if !ok || workspaceGroup != group {
			continue
		}
		if _, found := existing[inner]; !found {
			existing[inner] = workspace
		}
	}
	return existing
}

func selectInner(output string, group int, workspaces []i3.Workspace, state State, used map[int]bool) (innerSelection, bool) {
	existingOnOutput := make(map[int]bool)
	existingGlobally := make(map[int]i3.Workspace)
	for _, workspace := range workspaces {
		workspaceGroup, inner, ok := ParseWorkspace(workspace.Name)
		if !ok || workspaceGroup != group {
			continue
		}
		if workspace.Output == output {
			existingOnOutput[inner] = true
		}
		if _, found := existingGlobally[inner]; !found {
			existingGlobally[inner] = workspace
		}
	}

	preferred := state.LastInner(group, output, 0)
	if preferred > 0 && !used[preferred] && existingOnOutput[preferred] {
		return innerSelection{inner: preferred}, true
	}
	for inner := 1; inner <= MaxInner; inner++ {
		if existingOnOutput[inner] && !used[inner] {
			return innerSelection{inner: inner}, true
		}
	}
	if preferred > 0 && !used[preferred] {
		if _, exists := existingGlobally[preferred]; !exists {
			return innerSelection{inner: preferred}, true
		}
	}
	for inner := 1; inner <= MaxInner; inner++ {
		if used[inner] {
			continue
		}
		if _, exists := existingGlobally[inner]; !exists {
			return innerSelection{inner: inner}, true
		}
	}
	if preferred > 0 && !used[preferred] {
		if workspace, exists := existingGlobally[preferred]; exists && workspace.Output != output {
			return innerSelection{inner: preferred, moveFrom: workspace.Output}, true
		}
	}
	for inner := 1; inner <= MaxInner; inner++ {
		if used[inner] {
			continue
		}
		if workspace, exists := existingGlobally[inner]; exists && workspace.Output != output {
			return innerSelection{inner: inner, moveFrom: workspace.Output}, true
		}
	}
	return innerSelection{}, false
}

func switchCommands(group int, output string, selection innerSelection) []string {
	name := WorkspaceName(group, selection.inner)
	if selection.moveFrom != "" && selection.moveFrom != output {
		return []string{
			SwitchWorkspaceCommand(name),
			MoveWorkspaceToOutputCommand(output),
			FocusOutputCommand(output),
			SwitchWorkspaceCommand(name),
		}
	}
	return []string{
		FocusOutputCommand(output),
		SwitchWorkspaceCommand(name),
	}
}

func PlanSwitch(outputs []i3.Output, workspaces []i3.Workspace, state State, group int) SwitchPlan {
	plan := SwitchPlan{}
	if focused, ok := focusedWorkspace(workspaces); ok {
		plan.OriginalOutput = focused.Output
	}

	used := make(map[int]bool)
	for _, output := range activeOutputs(outputs) {
		selection, ok := selectInner(output.Name, group, workspaces, state, used)
		if !ok {
			continue
		}
		used[selection.inner] = true
		plan.Commands = append(plan.Commands, switchCommands(group, output.Name, selection)...)
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
	selection, ok := selectInner(focused.Output, group, workspaces, state, make(map[int]bool))
	if !ok {
		return "", fmt.Errorf("no inner workspace available on %s", focused.Output)
	}
	if selection.moveFrom != "" {
		return "", fmt.Errorf("no free inner workspace on %s", focused.Output)
	}
	return MoveWindowToWorkspaceCommand(WorkspaceName(group, selection.inner)), nil
}

func PlanInnerSwitch(workspaces []i3.Workspace, inner int) (string, int, string, error) {
	group, _, output, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return "", 0, "", fmt.Errorf("focused workspace is not part of a workspace group")
	}
	name := WorkspaceName(group, inner)
	for _, workspace := range workspaces {
		if workspace.Name == name {
			return SwitchWorkspaceCommand(name), group, workspace.Output, nil
		}
	}
	return SwitchWorkspaceCommand(name), group, output, nil
}

func PlanInnerMove(workspaces []i3.Workspace, inner int) (string, error) {
	group, _, _, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return "", fmt.Errorf("focused workspace is not part of a workspace group")
	}
	name := WorkspaceName(group, inner)
	for _, workspace := range workspaces {
		if workspace.Name == name {
			return MoveWindowToWorkspaceCommand(name), nil
		}
	}
	return MoveWindowToWorkspaceCommand(WorkspaceName(group, inner)), nil
}

func PlanAdopt(workspaces []i3.Workspace) []RenamePlan {
	used := make(map[int]map[int]bool)
	reserve := func(group, inner int) {
		if used[group] == nil {
			used[group] = make(map[int]bool)
		}
		used[group][inner] = true
	}
	for _, workspace := range workspaces {
		if group, inner, ok := ParseWorkspace(workspace.Name); ok {
			reserve(group, inner)
		}
	}

	planned := make([]RenamePlan, 0, len(workspaces))
	for _, workspace := range workspaces {
		if _, _, ok := ParseWorkspace(workspace.Name); ok {
			continue
		}

		group := 1
		inner := 0
		if legacyGroup, legacyInner, _, suffixed := ParseSuffixedWorkspace(workspace.Name); suffixed {
			group = legacyGroup
			inner = legacyInner
		} else if legacyGroup, _, legacy := ParseLegacyWorkspace(workspace.Name); legacy {
			inner = legacyGroup
		} else if plain, plainOk := ParsePlainWorkspace(workspace.Name, workspace.Num); plainOk {
			inner = plain
		} else {
			continue
		}

		if used[group] == nil {
			used[group] = make(map[int]bool)
		}
		if inner < 1 || used[group][inner] {
			inner = 0
			for candidate := 1; candidate <= MaxInner; candidate++ {
				if !used[group][candidate] {
					inner = candidate
					break
				}
			}
			if inner == 0 {
				continue
			}
		}
		target := WorkspaceName(group, inner)
		used[group][inner] = true
		planned = append(planned, RenamePlan{Old: workspace.Name, New: target})
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
		group, _, grouped := ParseWorkspace(visible.Name)
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
			workspaceGroup, inner, parsed := ParseWorkspace(workspace.Name)
			if !parsed || workspaceGroup != group || workspace.Output != output.Name {
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
		state = append(state, urgentGroupBadges(workspaces, output.Name, group)...)
	}
	return state
}

func urgentGroupBadges(workspaces []i3.Workspace, output string, activeGroup int) []i3.Workspace {
	urgent := make(map[int]i3.Workspace)
	for _, workspace := range workspaces {
		if workspace.Output != output || !workspace.Urgent {
			continue
		}
		group, _, ok := ParseWorkspace(workspace.Name)
		if !ok || group == activeGroup {
			continue
		}
		if _, found := urgent[group]; !found {
			urgent[group] = workspace
		}
	}

	groups := make([]int, 0, len(urgent))
	for group := range urgent {
		groups = append(groups, group)
	}
	sort.Ints(groups)

	badges := make([]i3.Workspace, 0, len(groups))
	for _, group := range groups {
		workspace := urgent[group]
		badges = append(badges, i3.Workspace{
			ID:     workspace.ID,
			Num:    -1,
			Name:   strconv.Itoa(group),
			Output: output,
			Urgent: true,
		})
	}
	return badges
}

func applyBarBlink(state []i3.Workspace, showUrgent bool) ([]i3.Workspace, bool) {
	hasUrgent := false
	for index := range state {
		if !state[index].Urgent {
			continue
		}
		hasUrgent = true
		if !showUrgent {
			state[index].Urgent = false
		}
	}
	return state, hasUrgent
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

	used := make(map[int]bool)
	for _, output := range active {
		visible, ok := visibleWorkspaceForOutput(workspaces, output.Name)
		if !ok {
			continue
		}
		visibleGroup, inner, parsed := ParseWorkspace(visible.Name)
		if parsed && visibleGroup == group {
			used[inner] = true
		}
	}

	commands := make([]string, 0, len(active)*2+1)
	for _, output := range active {
		visible, ok := visibleWorkspaceForOutput(workspaces, output.Name)
		if ok {
			visibleGroup, _, parsed := ParseWorkspace(visible.Name)
			if parsed && visibleGroup == group {
				continue
			}
		}
		selection, ok := selectInner(output.Name, group, workspaces, state, used)
		if !ok {
			continue
		}
		used[selection.inner] = true
		commands = append(commands, switchCommands(group, output.Name, selection)...)
	}
	if len(commands) > 0 && originalOutput != "" {
		commands = append(commands, FocusOutputCommand(originalOutput))
	}
	return commands
}

func PlanInnerSwap(tree i3.Tree, workspaces []i3.Workspace, first, second int) ([]string, error) {
	group, _, _, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return nil, fmt.Errorf("focused workspace is not part of a workspace group")
	}
	return planSwapNames(
		tree,
		WorkspaceName(group, first),
		WorkspaceName(group, second),
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
