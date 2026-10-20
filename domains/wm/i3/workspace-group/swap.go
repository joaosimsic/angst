package i3workspacegroup

import (
	"fmt"

	"go.i3wm.org/i3/v4"
)

func InnerSwap(first, second int) error {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}
	tree, err := i3.GetTree()
	if err != nil {
		return fmt.Errorf("get tree: %w", err)
	}
	commands, err := PlanInnerSwap(tree, workspaces, first, second)
	if err != nil {
		return err
	}
	return runCommands(commands)
}
