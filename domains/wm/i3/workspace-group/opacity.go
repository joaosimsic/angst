package i3workspacegroup

import (
	"encoding/binary"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/BurntSushi/xgb"
	"github.com/BurntSushi/xgb/xproto"
	"go.i3wm.org/i3/v4"
)

const (
	focusedOpacity         = 100
	defaultInactiveOpacity = 75
	opacityAtomName        = "_NET_WM_WINDOW_OPACITY"
)

var (
	appliedOpacity = make(map[int64]int)
	opacityConn    *xgb.Conn
	opacityAtom    xproto.Atom
)

func syncOpacity() error {
	tree, err := i3.GetTree()
	if err != nil {
		return fmt.Errorf("get tree: %w", err)
	}

	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}

	activeWorkspace := ""
	if focused, ok := focusedWorkspace(workspaces); ok {
		activeWorkspace = focused.Name
	}

	targets := opacityTargets(tree.Root, activeWorkspace)
	inactive := inactiveOpacity()

	for window, focused := range targets {
		opacity := inactive
		if focused {
			opacity = focusedOpacity
		}
		if appliedOpacity[window] == opacity {
			continue
		}
		if err := setWindowOpacity(window, opacity); err != nil {
			log.Printf("i3-workspace-group daemon: window %d opacity: %v", window, err)
			continue
		}
		appliedOpacity[window] = opacity
	}

	for window := range appliedOpacity {
		if _, ok := targets[window]; !ok {
			delete(appliedOpacity, window)
		}
	}

	return nil
}

func inactiveOpacity() int {
	value, err := strconv.Atoi(os.Getenv("ANGST_INACTIVE_OPACITY"))
	if err != nil || value < 10 || value > 100 {
		return defaultInactiveOpacity
	}
	return value
}

func setWindowOpacity(window int64, opacity int) error {
	conn, atom, err := opacityConnection()
	if err != nil {
		return err
	}

	value := uint32(float64(opacity)/100.0*float64(^uint32(0)) + 0.5)
	data := make([]byte, 4)
	binary.NativeEndian.PutUint32(data, value)

	return xproto.ChangePropertyChecked(
		conn,
		xproto.PropModeReplace,
		xproto.Window(window),
		atom,
		xproto.AtomCardinal,
		32,
		1,
		data,
	).Check()
}

func opacityConnection() (*xgb.Conn, xproto.Atom, error) {
	if opacityConn != nil {
		return opacityConn, opacityAtom, nil
	}

	conn, err := xgb.NewConn()
	if err != nil {
		return nil, 0, fmt.Errorf("connect to X: %w", err)
	}

	reply, err := xproto.InternAtom(
		conn,
		false,
		uint16(len(opacityAtomName)),
		opacityAtomName,
	).Reply()
	if err != nil {
		conn.Close()
		return nil, 0, fmt.Errorf("intern %s: %w", opacityAtomName, err)
	}

	opacityConn = conn
	opacityAtom = reply.Atom
	return opacityConn, opacityAtom, nil
}

func opacityTargets(root *i3.Node, activeWorkspace string) map[int64]bool {
	targets := make(map[int64]bool)

	var walk func(node *i3.Node)
	walk = func(node *i3.Node) {
		if node.Type == i3.WorkspaceNode {
			windows := windowIDs(node)
			if len(windows) == 0 {
				return
			}
			if node.Name != activeWorkspace {
				for _, window := range windows {
					targets[window] = true
				}
				return
			}
			focused := focusedWindowID(node)
			for _, window := range windows {
				targets[window] = window == focused
			}
			for _, window := range floatingWindowIDs(node) {
				targets[window] = true
			}
			return
		}
		for _, child := range node.Nodes {
			walk(child)
		}
		for _, child := range node.FloatingNodes {
			walk(child)
		}
	}

	walk(root)
	for _, window := range stickyWindowIDs(root) {
		targets[window] = true
	}
	return targets
}

func stickyWindowIDs(node *i3.Node) []int64 {
	windows := make([]int64, 0)
	var walk func(node *i3.Node)
	walk = func(node *i3.Node) {
		if node.Window != 0 && node.Sticky {
			windows = append(windows, node.Window)
			return
		}
		for _, child := range node.Nodes {
			walk(child)
		}
		for _, child := range node.FloatingNodes {
			walk(child)
		}
	}
	walk(node)
	return windows
}

func floatingWindowIDs(node *i3.Node) []int64 {
	windows := make([]int64, 0)
	var walk func(node *i3.Node)
	walk = func(node *i3.Node) {
		if node.Window != 0 {
			windows = append(windows, node.Window)
			return
		}
		for _, child := range node.Nodes {
			walk(child)
		}
		for _, child := range node.FloatingNodes {
			walk(child)
		}
	}
	for _, child := range node.FloatingNodes {
		walk(child)
	}
	return windows
}

func windowIDs(node *i3.Node) []int64 {
	windows := make([]int64, 0)
	var walk func(node *i3.Node)
	walk = func(node *i3.Node) {
		if node.Window != 0 {
			windows = append(windows, node.Window)
			return
		}
		for _, child := range node.Nodes {
			walk(child)
		}
		for _, child := range node.FloatingNodes {
			walk(child)
		}
	}
	walk(node)
	return windows
}

func focusedWindowID(node *i3.Node) int64 {
	current := node
	for {
		if current.Window != 0 {
			return current.Window
		}
		if len(current.Focus) == 0 {
			break
		}
		nextID := current.Focus[0]
		next := directChild(current, nextID)
		if next == nil {
			next = current.FindChild(func(child *i3.Node) bool {
				return child.ID == nextID
			})
		}
		if next == nil {
			break
		}
		current = next
	}

	if window := firstWindow(node); window != 0 {
		return window
	}
	return 0
}

func directChild(node *i3.Node, id i3.NodeID) *i3.Node {
	for _, child := range node.Nodes {
		if child.ID == id {
			return child
		}
	}
	for _, child := range node.FloatingNodes {
		if child.ID == id {
			return child
		}
	}
	return nil
}

func firstWindow(node *i3.Node) int64 {
	if node.Window != 0 {
		return node.Window
	}
	for _, child := range node.Nodes {
		if window := firstWindow(child); window != 0 {
			return window
		}
	}
	for _, child := range node.FloatingNodes {
		if window := firstWindow(child); window != 0 {
			return window
		}
	}
	return 0
}
