package i3workspacegroup

import (
	"fmt"

	"go.i3wm.org/i3/v4"
)

func AdoptIfNeeded() (int, error) {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return 0, fmt.Errorf("get workspaces: %w", err)
	}
	if len(PlanAdopt(workspaces)) == 0 {
		return 0, nil
	}
	return Adopt()
}

func Adopt() (int, error) {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return 0, fmt.Errorf("get workspaces: %w", err)
	}

	renamed := 0
	for _, plan := range PlanAdopt(workspaces) {
		command := RenameWorkspaceCommand(plan.Old, plan.New)
		if _, err := i3.RunCommand(command); err != nil {
			current, getErr := i3.GetWorkspaces()
			if getErr == nil {
				_, oldExists := lookupWorkspace(current, plan.Old)
				_, newExists := lookupWorkspace(current, plan.New)
				if !oldExists && newExists {
					renamed++
					continue
				}
			}
			return renamed, fmt.Errorf("%s: %w", command, err)
		}
		renamed++
	}

	workspaces, err = i3.GetWorkspaces()
	if err != nil {
		return renamed, fmt.Errorf("get workspaces after adopt: %w", err)
	}
	seed := make(map[int]map[string]int)
	for _, workspace := range workspaces {
		if !workspace.Visible {
			continue
		}
		group, inner, ok := ParseWorkspace(workspace.Name)
		if !ok {
			continue
		}
		if seed[group] == nil {
			seed[group] = make(map[string]int)
		}
		seed[group][workspace.Output] = inner
	}
	if err := seedState(statePath(), seed); err != nil {
		return renamed, fmt.Errorf("seed state: %w", err)
	}
	return renamed, nil
}
