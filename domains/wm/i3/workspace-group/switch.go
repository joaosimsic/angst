package i3workspacegroup

import (
	"fmt"
	"log"

	"go.i3wm.org/i3/v4"
)

func loadCurrentState() State {
	state, err := loadState(statePath())
	if err != nil {
		log.Printf("i3-workspace-group: %v", err)
		return newState()
	}
	return state
}

func rememberFocused(workspaces []i3.Workspace) {
	group, inner, output, ok := parseFocusedWorkspace(workspaces)
	if !ok {
		return
	}
	if err := updateState(statePath(), group, output, inner); err != nil {
		log.Printf("i3-workspace-group: %v", err)
	}
}

func Switch(group int) error {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}
	rememberFocused(workspaces)

	outputs, err := i3.GetOutputs()
	if err != nil {
		return fmt.Errorf("get outputs: %w", err)
	}
	plan := PlanSwitch(outputs, workspaces, loadCurrentState(), group)
	if len(plan.Commands) == 0 {
		return fmt.Errorf("no active outputs")
	}
	if err := runCommands(plan.Commands); err != nil {
		if plan.OriginalOutput != "" {
			_, _ = i3.RunCommand(FocusOutputCommand(plan.OriginalOutput))
		}
		return err
	}
	return nil
}

func MoveTop(group int) error {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}
	command, err := PlanMoveTop(workspaces, loadCurrentState(), group)
	if err != nil {
		return err
	}
	return runCommands([]string{command})
}

func Inner(inner int) error {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}
	command, group, output, err := PlanInnerSwitch(workspaces, inner)
	if err != nil {
		return err
	}
	if err := runCommands([]string{command}); err != nil {
		return err
	}
	if err := updateState(statePath(), group, output, inner); err != nil {
		log.Printf("i3-workspace-group: %v", err)
	}
	return nil
}

func InnerMove(inner int) error {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}
	command, err := PlanInnerMove(workspaces, inner)
	if err != nil {
		return err
	}
	return runCommands([]string{command})
}
