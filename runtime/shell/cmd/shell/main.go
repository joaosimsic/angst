package main

import (
	"os"
	"shell"
)

func main() {
	os.Exit(shell.Run(os.Args[1:]))
}
