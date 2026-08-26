package main

import (
	"os"
	"analyze"
)

func main() {
	os.Exit(analyze.Run(os.Args[1:]))
}
