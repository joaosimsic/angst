package projects

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"time"
)

func keys(path string) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	seen := map[string]bool{}
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		eq := strings.IndexByte(line, '=')
		if eq <= 0 {
			continue
		}
		k := line[:eq]
		if !isKeyName(k) {
			continue
		}
		if !seen[k] {
			seen[k] = true
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out
}

func isKeyName(k string) bool {
	if k == "" {
		return false
	}
	c := k[0]
	if !(c == '_' || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z') {
		return false
	}
	for i := 1; i < len(k); i++ {
		c = k[i]
		if !(c == '_' || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9') {
			return false
		}
	}
	return true
}

func sha256hex(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func copyChmod(src, dst string, perm os.FileMode) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := os.WriteFile(dst, data, perm); err != nil {
		return err
	}
	return os.Chmod(dst, perm)
}

func readTrimmed(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(data), "\n")
}

func clone(gitSSH, remote, target string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	c := exec.CommandContext(ctx, "git", "clone", remote, target)
	c.Env = append(os.Environ(), "GIT_SSH_COMMAND="+gitSSH)
	out, err := c.CombinedOutput()
	if err != nil {
		if len(out) > 0 {
			return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(out)))
		}
		return err
	}
	return nil
}

func envKeyDiff(storePath, localPath string) {
	a := keys(storePath)
	b := keys(localPath)
	if len(a) == 0 && len(b) == 0 {
		return
	}
	onlyA := map[string]bool{}
	for _, k := range a {
		onlyA[k] = true
	}
	for _, k := range b {
		delete(onlyA, k)
	}
	var storeOnly []string
	for _, k := range a {
		if onlyA[k] {
			storeOnly = append(storeOnly, k)
		}
	}
	onlyB := map[string]bool{}
	for _, k := range b {
		onlyB[k] = true
	}
	for _, k := range a {
		delete(onlyB, k)
	}
	var localOnly []string
	for _, k := range b {
		if onlyB[k] {
			localOnly = append(localOnly, k)
		}
	}
	for _, k := range storeOnly {
		fmt.Fprintf(os.Stderr, "  store: %s\n", k)
	}
	for _, k := range localOnly {
		fmt.Fprintf(os.Stderr, "  local: %s\n", k)
	}
}
