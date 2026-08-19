package projects

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"angst/internal/cmd"
	"angst/internal/shared"
	"angst/internal/scope"
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

func randomID() string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

func unknownProject(name string) int {
	fmt.Fprintf(os.Stderr, "error: unknown project '%s'\n", name)
	return shared.ExitError
}

func sopsDecrypt(s scope.Scope, file string) ([]byte, error) {
	c := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", file)
	c.Env = append(os.Environ(), "SOPS_AGE_KEY_FILE="+scope.AgeKeyfile(s, scope.EnvOverride))
	c.Stderr = os.Stderr
	var out bytes.Buffer
	c.Stdout = &out
	if err := c.Run(); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func sopsDecryptToFile(s scope.Scope, file, out string) error {
	c := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", "--output", out, file)
	c.Env = append(os.Environ(), "SOPS_AGE_KEY_FILE="+scope.AgeKeyfile(s, scope.EnvOverride))
	c.Stderr = os.Stderr
	return c.Run()
}

func encrypt(s scope.Scope, plain, target string) error {
	recipient, err := scope.RecipientFor(s, scope.EnvOverride)
	if err != nil {
		return err
	}
	keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
	work, err := os.MkdirTemp("", "angst-encrypt-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(work)

	sopsConf := fmt.Sprintf("---\ncreation_rules:\n  - path_regex: .*\n    age: |\n      %s\n", recipient)
	if err := os.WriteFile(filepath.Join(work, ".sops.yaml"), []byte(sopsConf), 0o600); err != nil {
		return err
	}
	data, err := os.ReadFile(plain)
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(work, "plain"), data, 0o600); err != nil {
		return err
	}
	return cmd.RunDir(work, []string{"SOPS_AGE_KEY_FILE=" + keyfile},
		"sops", "-e", "--input-type", "binary", "--output-type", "binary", "--output", target, "plain")
}

func clone(gitSSH, remote, target string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	c := exec.CommandContext(ctx, "git", "clone", remote, target)
	c.Env = append(os.Environ(), "GIT_SSH_COMMAND="+gitSSH)
	c.Stdout = nil
	c.Stderr = nil
	return c.Run()
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

func missingKeys(examplePath, envPath string) []string {
	a := keys(examplePath)
	b := keys(envPath)
	set := map[string]bool{}
	for _, k := range b {
		set[k] = true
	}
	var out []string
	for _, k := range a {
		if !set[k] {
			out = append(out, k)
		}
	}
	return out
}
