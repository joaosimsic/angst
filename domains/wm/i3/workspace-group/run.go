package i3workspacegroup

import (
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func Run(args []string) int {
	if len(args) == 0 {
		usage(os.Stderr)
		return 2
	}

	switch args[0] {
	case "switch":
		group, err := singleArgGroup(args[1:])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := Switch(group); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group switch: %v\n", err)
			return 1
		}
	case "move":
		group, err := singleArgGroup(args[1:])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := MoveTop(group); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group move: %v\n", err)
			return 1
		}
	case "inner":
		inner, err := singleArgInner(args[1:])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := Inner(inner); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group inner: %v\n", err)
			return 1
		}
	case "inner-move":
		inner, err := singleArgInner(args[1:])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := InnerMove(inner); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group inner-move: %v\n", err)
			return 1
		}
	case "inner-swap":
		if len(args) != 3 {
			fmt.Fprintln(os.Stderr, "usage: i3-workspace-group inner-swap <inner-a> <inner-b>")
			return 2
		}
		first, err := parseInner(args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		second, err := parseInner(args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := InnerSwap(first, second); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group inner-swap: %v\n", err)
			return 1
		}
	case "adopt":
		renamed, err := Adopt()
		if err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group adopt: %v\n", err)
			return 1
		}
		fmt.Fprintf(os.Stderr, "i3-workspace-group adopt: renamed %d workspace(s)\n", renamed)
	case "bar":
		urgentColor, err := singleArgColor(args[1:])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := Bar(urgentColor); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group bar: %v\n", err)
			return 1
		}
	case "daemon":
		if err := Daemon(); err != nil {
			fmt.Fprintf(os.Stderr, "i3-workspace-group daemon: %v\n", err)
			return 1
		}
	case "-h", "--help", "help":
		usage(os.Stdout)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", args[0])
		usage(os.Stderr)
		return 2
	}
	return 0
}

func singleArgGroup(args []string) (int, error) {
	if len(args) != 1 {
		return 0, fmt.Errorf("expected one top-level workspace argument")
	}
	return parseNumber(args[0], MaxGroup, "workspace")
}

func singleArgInner(args []string) (int, error) {
	if len(args) != 1 {
		return 0, fmt.Errorf("expected one inner workspace argument")
	}
	return parseInner(args[0])
}

func singleArgColor(args []string) (string, error) {
	if len(args) != 1 {
		return "", fmt.Errorf("expected one six-digit hex color argument")
	}
	value := strings.TrimPrefix(args[0], "#")
	if len(value) != 6 {
		return "", fmt.Errorf("bar urgent color must be a six-digit hex color")
	}
	if _, err := hex.DecodeString(value); err != nil {
		return "", fmt.Errorf("bar urgent color must be a six-digit hex color")
	}
	return "#" + value, nil
}

func parseInner(value string) (int, error) {
	return parseNumber(value, MaxInner, "inner workspace")
}

func parseNumber(value string, max int, label string) (int, error) {
	number, err := strconv.Atoi(value)
	if err != nil || number < 1 || number > max {
		return 0, fmt.Errorf("%s must be an integer between 1 and %d", label, max)
	}
	return number, nil
}

func usage(output *os.File) {
	fmt.Fprint(output, `Usage:
  i3-workspace-group switch GROUP
  i3-workspace-group move GROUP
  i3-workspace-group inner INNER
  i3-workspace-group inner-move INNER
  i3-workspace-group inner-swap INNER_A INNER_B
  i3-workspace-group adopt
  i3-workspace-group bar URGENT_COLOR
  i3-workspace-group daemon
`)
}
