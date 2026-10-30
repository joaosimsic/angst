package main

import (
	"os"

	"i3workspacegroup"
)

func main() {
	os.Exit(i3workspacegroup.Run(os.Args[1:]))
}
