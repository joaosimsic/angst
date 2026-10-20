package i3workspacegroup

import (
	"fmt"

	"go.i3wm.org/i3/v4"
)

func runCommands(commands []string) error {
	for _, command := range commands {
		if _, err := i3.RunCommand(command); err != nil {
			return fmt.Errorf("%s: %w", command, err)
		}
	}
	return nil
}

func lookupWorkspace(workspaces []i3.Workspace, name string) (i3.Workspace, bool) {
	for _, workspace := range workspaces {
		if workspace.Name == name {
			return workspace, true
		}
	}
	return i3.Workspace{}, false
}
