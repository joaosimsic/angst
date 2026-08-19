package system

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

func usage() {
	fmt.Print(`Usage:
  angst login-shell --shell NAME --home DIR --user USER
  angst ssh-add-keys KEY...
  angst provision-ssh-key --user USER --home DIR --secrets-dir DIR
`)
}

func dash(first string, rest ...string) string {
	s := first
	for _, r := range rest {
		s += " " + r
	}
	return s
}

func quietRun(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdin = os.Stdin
	c.Stdout = os.Stdout
	c.Stderr = nil
	return c.Run()
}

func quote(s string) string {
	return strconv.Quote(s)
}

func singleQuote(s string) string {
	return "'" + s + "'"
}

func isExecutable(path string) bool {
	if st, err := os.Stat(path); err == nil {
		return st.Mode().IsRegular() && st.Mode().Perm()&0o111 != 0
	}
	return false
}

func lookPath(name string) string {
	p, err := exec.LookPath(name)
	if err != nil {
		return ""
	}
	return p
}

func readLines(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	return strings.Split(strings.TrimRight(string(data), "\n"), "\n")
}

func containsLine(lines []string, needle string) bool {
	for _, l := range lines {
		if l == needle {
			return true
		}
	}
	return false
}
