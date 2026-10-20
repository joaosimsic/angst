package i3workspacegroup

import (
	"fmt"
	"strconv"
	"strings"

	"go.i3wm.org/i3/v4"
)

const (
	MaxGroup = 10
	MaxInner = 10
)

func Groups() []int {
	groups := make([]int, 0, MaxGroup)
	for group := 1; group <= MaxGroup; group++ {
		groups = append(groups, group)
	}
	return groups
}

func WorkspaceName(group, inner int) string {
	return fmt.Sprintf("%d:%d", group, inner)
}

func ParseWorkspace(name string) (group, inner int, ok bool) {
	parts := strings.Split(name, ":")
	if len(parts) != 2 {
		return 0, 0, false
	}
	group, groupErr := strconv.Atoi(parts[0])
	inner, innerErr := strconv.Atoi(parts[1])
	if groupErr != nil || innerErr != nil {
		return 0, 0, false
	}
	if group < 1 || group > MaxGroup || inner < 1 || inner > MaxInner {
		return 0, 0, false
	}
	return group, inner, true
}

func ParseSuffixedWorkspace(name string) (group, inner int, output string, ok bool) {
	parts := strings.SplitN(name, ":", 3)
	if len(parts) != 3 || parts[2] == "" {
		return 0, 0, "", false
	}
	group, groupErr := strconv.Atoi(parts[0])
	inner, innerErr := strconv.Atoi(parts[1])
	if groupErr != nil || innerErr != nil {
		return 0, 0, "", false
	}
	if group < 1 || group > MaxGroup || inner < 1 || inner > MaxInner {
		return 0, 0, "", false
	}
	return group, inner, parts[2], true
}

func ParseLegacyWorkspace(name string) (group int, output string, ok bool) {
	parts := strings.SplitN(name, ":", 2)
	if len(parts) != 2 || parts[1] == "" || strings.Contains(parts[1], ":") {
		return 0, "", false
	}
	group, err := strconv.Atoi(parts[0])
	if err != nil || group < 1 || group > MaxGroup {
		return 0, "", false
	}
	return group, parts[1], true
}

func ParsePlainWorkspace(name string, num int64) (int, bool) {
	if num >= 1 && num <= MaxGroup && !strings.Contains(name, ":") {
		return int(num), true
	}
	return 0, false
}

func QuoteI3(value string) string {
	replacer := strings.NewReplacer(`\`, `\\`, `"`, `\"`)
	return `"` + replacer.Replace(value) + `"`
}

func FocusOutputCommand(output string) string {
	return "focus output " + QuoteI3(output)
}

func SwitchWorkspaceCommand(name string) string {
	return "workspace --no-auto-back-and-forth " + QuoteI3(name)
}

func MoveWindowToWorkspaceCommand(name string) string {
	return "move container to workspace " + QuoteI3(name)
}

func MoveWorkspaceToOutputCommand(output string) string {
	return "move workspace to output " + QuoteI3(output)
}

func SwapContainersCommand(first, second i3.NodeID) string {
	return fmt.Sprintf("[con_id=%d] swap container with con_id %d", first, second)
}

func MoveContainerToWorkspaceCommand(id i3.NodeID, name string) string {
	return fmt.Sprintf("[con_id=%d] move container to workspace %s", id, QuoteI3(name))
}

func RenameWorkspaceCommand(oldName, newName string) string {
	return "rename workspace " + QuoteI3(oldName) + " to " + QuoteI3(newName)
}
