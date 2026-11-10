package i3workspacegroup

import (
	"fmt"
	"strings"

	"go.i3wm.org/i3/v4"
)

type floatingWindow struct {
	id     i3.NodeID
	output string
	sticky bool
}

var stickyPins = make(map[i3.NodeID]string)

func floatingWindows(root *i3.Node) []floatingWindow {
	windows := make([]floatingWindow, 0)

	var walk func(node *i3.Node, output string, floating bool)
	walk = func(node *i3.Node, output string, floating bool) {
		if node == nil {
			return
		}

		switch node.Type {
		case i3.OutputNode:
			if strings.HasPrefix(node.Name, "__") {
				return
			}
			output = node.Name
		case i3.WorkspaceNode:
			if strings.HasPrefix(node.Name, "__") {
				return
			}
		}

		if floating && node.Window != 0 {
			windows = append(windows, floatingWindow{
				id:     node.ID,
				output: output,
				sticky: node.Sticky,
			})
			return
		}

		for _, child := range node.Nodes {
			walk(child, output, floating)
		}
		for _, child := range node.FloatingNodes {
			walk(child, output, true)
		}
	}

	walk(root, "", false)
	return windows
}

func nodeIsSticky(node *i3.Node) bool {
	if node == nil {
		return false
	}
	if node.Sticky {
		return true
	}
	for _, child := range node.Nodes {
		if nodeIsSticky(child) {
			return true
		}
	}
	for _, child := range node.FloatingNodes {
		if nodeIsSticky(child) {
			return true
		}
	}
	return false
}

func syncFloatingSticky() error {
	tree, err := i3.GetTree()
	if err != nil {
		return fmt.Errorf("get tree: %w", err)
	}

	commands := make([]string, 0)
	for _, window := range floatingWindows(tree.Root) {
		if window.sticky || window.output == "" {
			continue
		}
		commands = append(commands, fmt.Sprintf("[con_id=%d] sticky enable", window.id))
	}
	return runCommands(commands)
}

func enableSticky(id i3.NodeID) error {
	return runCommands([]string{fmt.Sprintf("[con_id=%d] sticky enable", id)})
}

func planStickyPins(tree *i3.Node, workspaces []i3.Workspace, pins map[i3.NodeID]string) []string {
	visible := make(map[string]string)
	for _, workspace := range workspaces {
		if workspace.Visible {
			visible[workspace.Output] = workspace.Name
		}
	}

	current := make(map[i3.NodeID]bool)
	commands := make([]string, 0)

	for _, window := range floatingWindows(tree) {
		if !window.sticky || window.output == "" {
			continue
		}
		current[window.id] = true

		pinnedOutput, pinned := pins[window.id]
		if !pinned {
			pins[window.id] = window.output
			continue
		}
		if pinnedOutput == window.output {
			continue
		}

		workspace, visibleOnPinned := visible[pinnedOutput]
		if !visibleOnPinned {
			pins[window.id] = window.output
			continue
		}
		commands = append(commands, MoveContainerToWorkspaceCommand(window.id, workspace))
	}

	for id := range pins {
		if !current[id] {
			delete(pins, id)
		}
	}

	return commands
}

func syncStickyPins() error {
	tree, err := i3.GetTree()
	if err != nil {
		return fmt.Errorf("get tree: %w", err)
	}

	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}

	return runCommands(planStickyPins(tree.Root, workspaces, stickyPins))
}
