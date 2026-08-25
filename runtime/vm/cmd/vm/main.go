package main

import (
	"os"
	"vm"
)

func main() {
	os.Exit(vm.Run(os.Args[1:]))
}
