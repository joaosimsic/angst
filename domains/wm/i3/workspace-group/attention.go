package i3workspacegroup

import (
	"fmt"
	"sort"

	"go.i3wm.org/i3/v4"
)

type attentionTarget struct {
	Key      string
	WindowID i3.NodeID
	Session  string
	TabID    uint32
	Position int
}

func windowKey(container i3.NodeID) string {
	return fmt.Sprintf("w\x1f%d", container)
}

func windowAttentionTargets(tree i3.Tree) []attentionTarget {
	targets := make([]attentionTarget, 0)
	var walk func(node *i3.Node)
	walk = func(node *i3.Node) {
		if node == nil {
			return
		}
		if node.Window != 0 && node.Urgent {
			targets = append(targets, attentionTarget{
				Key:      windowKey(node.ID),
				WindowID: node.ID,
			})
		}
		for _, child := range node.Nodes {
			walk(child)
		}
		for _, child := range node.FloatingNodes {
			walk(child)
		}
	}
	walk(tree.Root)
	return targets
}

func scanAttention() ([]attentionTarget, bool, error) {
	tree, err := i3.GetTree()
	if err != nil {
		return nil, false, fmt.Errorf("get tree: %w", err)
	}
	targets := windowAttentionTargets(tree)

	sessions, err := zellijSessions()
	if err != nil {
		return targets, false, nil
	}
	if len(sessions) == 0 {
		return targets, true, nil
	}
	windows := zellijWindows(tree, sessions)
	focused := focusedContainerID(tree)
	complete := true
	for _, session := range sessions {
		sessionWindows := windows[session]
		if len(sessionWindows) == 0 {
			continue
		}
		window := preferredWindow(sessionWindows, focused)
		tabs, err := zellijTabs(session)
		if err != nil {
			complete = false
			continue
		}
		for _, tab := range tabs {
			if !tab.HasBell && !tab.FlashingBell {
				continue
			}
			targets = append(targets, attentionTarget{
				Key:      bellKey(session, tab.TabID),
				WindowID: window,
				Session:  session,
				TabID:    tab.TabID,
				Position: tab.Position,
			})
		}
	}

	sort.Slice(targets, func(first, second int) bool {
		return targets[first].Key < targets[second].Key
	})
	return targets, complete, nil
}

func syncAttention() (State, []attentionTarget, error) {
	targets, complete, err := scanAttention()
	if err != nil {
		return newState(), nil, err
	}
	current := make(map[string]bool, len(targets))
	for _, target := range targets {
		current[target.Key] = true
	}
	state, err := updateUrgent(statePath(), current, !complete)
	if err != nil {
		return newState(), targets, err
	}
	return state, targets, nil
}

func oldestTarget(targets []attentionTarget, state State) (attentionTarget, bool) {
	var oldest attentionTarget
	oldestSeq := int64(0)
	found := false
	for _, target := range targets {
		seq, ok := state.Urgent[target.Key]
		if !ok {
			continue
		}
		if !found || seq < oldestSeq {
			oldest = target
			oldestSeq = seq
			found = true
		}
	}
	return oldest, found
}

func targetsForWindow(targets []attentionTarget, window i3.NodeID) []attentionTarget {
	filtered := make([]attentionTarget, 0)
	for _, target := range targets {
		if target.WindowID == window {
			filtered = append(filtered, target)
		}
	}
	return filtered
}

func oldestZellijTarget(targets []attentionTarget, state State) (attentionTarget, bool) {
	zellijTargets := make([]attentionTarget, 0)
	for _, target := range targets {
		if target.Session != "" {
			zellijTargets = append(zellijTargets, target)
		}
	}
	return oldestTarget(zellijTargets, state)
}
