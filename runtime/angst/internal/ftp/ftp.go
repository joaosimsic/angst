package ftp

import (
	"fmt"
	"os"

	"angst/internal/shared"
)

func Run(args []string) int {
	if len(args) == 0 {
		usage()
		return shared.ExitUsage
	}
	cmdName := args[0]
	args = args[1:]
	switch cmdName {
	case "decrypt":
		return cmdDecrypt(args)
	case "transform":
		return cmdTransform(args)
	case "mount":
		return cmdMount(args)
	case "unmount":
		return cmdUnmount(args)
	case "-h", "--help":
		usage()
		return shared.ExitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown ftp command: %s\n", cmdName)
		usage()
		return shared.ExitUsage
	}
}

func usage() {
	fmt.Print(`Usage:
  angst ftp decrypt --home DIR --conf SOURCE:DEST [...]
  angst ftp transform --conf FILE --ini FILE
  angst ftp mount --conf FILE --mount-point DIR [--remote-path PATH]
  angst ftp unmount --mount-point DIR
`)
}
