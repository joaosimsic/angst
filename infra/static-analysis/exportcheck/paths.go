package main

import (
	"path"
	"strings"
)

func isTestPath(file string) bool {
	base := path.Base(file)
	if base == "test.nix" || strings.HasSuffix(base, ".test.nix") || strings.HasSuffix(base, "_test.nix") {
		return true
	}

	for part := range strings.SplitSeq(file, "/") {
		switch part {
		case "tests", "testdata", "fixtures":
			return true
		}
	}

	return false
}

func findModuleRoot(file string, trackedFiles map[string]struct{}) string {
	directory := path.Dir(file)

	for {
		if _, ok := trackedFiles[path.Join(directory, "default.nix")]; ok {
			return directory
		}

		if directory == "." || directory == "/" || directory == "" {
			return ""
		}

		directory = path.Dir(directory)
	}
}
