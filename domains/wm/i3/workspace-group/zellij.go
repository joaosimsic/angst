package i3workspacegroup

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"time"

	"go.i3wm.org/i3/v4"
)

const zellijCommandTimeout = 1500 * time.Millisecond

type zellijTab struct {
	Position     int    `json:"position"`
	TabID        uint32 `json:"tab_id"`
	HasBell      bool   `json:"has_bell_notification"`
	FlashingBell bool   `json:"is_flashing_bell"`
	Active       bool   `json:"active"`
}

type zellijBell struct {
	Session  string
	WindowID i3.NodeID
	TabID    uint32
	Position int
}

func decodeZellijTabs(data []byte) ([]zellijTab, error) {
	var tabs []zellijTab
	if err := json.Unmarshal(data, &tabs); err != nil {
		return nil, fmt.Errorf("parse zellij tabs: %w", err)
	}
	return tabs, nil
}

func zellijSessions() ([]string, error) {
	if _, err := exec.LookPath("zellij"); err != nil {
		return nil, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), zellijCommandTimeout)
	defer cancel()

	output, err := exec.CommandContext(ctx, "zellij", "list-sessions", "-n", "-s").Output()
	if err != nil {
		return nil, fmt.Errorf("list zellij sessions: %w", err)
	}

	sessions := make([]string, 0)
	for _, line := range strings.Split(string(output), "\n") {
		session := strings.TrimSpace(line)
		if session != "" {
			sessions = append(sessions, session)
		}
	}
	sort.Strings(sessions)
	return sessions, nil
}

func zellijTabs(session string) ([]zellijTab, error) {
	ctx, cancel := context.WithTimeout(context.Background(), zellijCommandTimeout)
	defer cancel()

	output, err := exec.CommandContext(
		ctx,
		"zellij",
		"--session",
		session,
		"action",
		"list-tabs",
		"--all",
		"--json",
	).Output()
	if err != nil {
		return nil, fmt.Errorf("list zellij tabs for %s: %w", session, err)
	}
	return decodeZellijTabs(output)
}

func sessionForTitle(title string, sessions []string) (string, bool) {
	best := ""
	for _, session := range sessions {
		if !strings.Contains(title, session) {
			continue
		}
		if len(session) > len(best) {
			best = session
		}
	}
	return best, best != ""
}

func zellijWindows(tree i3.Tree, sessions []string) map[string][]i3.NodeID {
	windows := make(map[string][]i3.NodeID)
	var walk func(node *i3.Node)
	walk = func(node *i3.Node) {
		if node == nil {
			return
		}
		if node.Window != 0 {
			if session, ok := sessionForTitle(node.Name, sessions); ok {
				windows[session] = append(windows[session], node.ID)
			}
		}
		for _, child := range node.Nodes {
			walk(child)
		}
		for _, child := range node.FloatingNodes {
			walk(child)
		}
	}
	walk(tree.Root)
	return windows
}

func focusedContainerID(tree i3.Tree) i3.NodeID {
	if tree.Root == nil {
		return 0
	}
	focused := tree.Root.FindChild(func(node *i3.Node) bool {
		return node.Window != 0 && node.Focused
	})
	if focused == nil {
		return 0
	}
	return focused.ID
}

func preferredWindow(windows []i3.NodeID, focused i3.NodeID) i3.NodeID {
	for _, window := range windows {
		if window == focused {
			return window
		}
	}
	if len(windows) == 0 {
		return 0
	}
	return windows[0]
}

func focusZellijTab(bell zellijBell) error {
	ctx, cancel := context.WithTimeout(context.Background(), zellijCommandTimeout)
	defer cancel()

	output, err := exec.CommandContext(
		ctx,
		"zellij",
		"--session",
		bell.Session,
		"action",
		"go-to-tab-by-id",
		strconv.FormatUint(uint64(bell.TabID), 10),
	).CombinedOutput()
	if err != nil {
		return fmt.Errorf("go to zellij tab %d: %w: %s", bell.TabID, err, strings.TrimSpace(string(output)))
	}
	return nil
}
