package i3workspacegroup

import (
	"fmt"
	"log"

	"go.i3wm.org/i3/v4"
)

func FocusOldest() error {
	if _, err := groupedWorkspaces(); err != nil {
		return err
	}

	state, targets, err := syncAttention()
	if err != nil {
		log.Printf("i3-workspace-group urgent: %v", err)
		state = loadCurrentState()
	}

	target, ok := oldestTarget(targets, state)
	if !ok {
		return nil
	}
	if target.WindowID != 0 {
		if err := focusWindow(target.WindowID); err != nil {
			return err
		}
	}
	if target.Session != "" {
		return focusZellijTab(zellijBell{
			Session:  target.Session,
			WindowID: target.WindowID,
			TabID:    target.TabID,
			Position: target.Position,
		})
	}

	bell, ok := oldestZellijTarget(targetsForWindow(targets, target.WindowID), state)
	if !ok {
		return nil
	}
	return focusZellijTab(zellijBell{
		Session:  bell.Session,
		WindowID: bell.WindowID,
		TabID:    bell.TabID,
		Position: bell.Position,
	})
}

func focusWindow(window i3.NodeID) error {
	command := fmt.Sprintf("[con_id=%d] focus", window)
	if _, err := i3.RunCommand(command); err != nil {
		return fmt.Errorf("%s: %w", command, err)
	}
	return nil
}
