package main

import (
	"analyze"
	"os"
)

func main() {
	os.Exit(analyze.Run(os.Args[1:]))
}
