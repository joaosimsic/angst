package ftp

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"angst/internal/shared"
	"angst/internal/scope"
)

func cmdDecrypt(args []string) int {
	pairs := []string{}
	homeDir := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--home":
			if i+1 < len(args) {
				homeDir = args[i+1]
				i++
			}
		case "--conf":
			if i+1 < len(args) {
				pairs = append(pairs, args[i+1])
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp decrypt option: %s\n", args[i])
			usage()
			return shared.ExitUsage
		}
	}

	workKey := scope.AgeKeyfile(scope.Work, scope.EnvOverride)
	if _, err := os.Stat(workKey); err != nil {
		fmt.Fprintf(os.Stderr, "warn: work age key not found at %s; cannot decrypt ftp configs\n", workKey)
		return shared.ExitOK
	}

	secretsDir := filepath.Join(homeDir, ".secrets", "ftp")
	_ = os.MkdirAll(secretsDir, 0o700)
	_ = os.Chmod(filepath.Join(homeDir, ".secrets"), 0o700)
	_ = os.Chmod(secretsDir, 0o700)

	for _, p := range pairs {
		src, dst := splitConf(p)
		if _, err := os.Stat(src); err != nil {
			fmt.Fprintf(os.Stderr, "warn: ftp config not found at %s\n", src)
			continue
		}
		tmp := filepath.Join(homeDir, dst+".tmp")
		c := exec.Command("sops", "-d", "--input-type", "binary", "--output-type", "binary", src)
		c.Env = append(os.Environ(), "SOPS_AGE_KEY_FILE="+workKey)
		c.Stderr = nil
		var out bytes.Buffer
		c.Stdout = &out
		if err := c.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s\n", src)
			_ = os.Remove(tmp)
			continue
		}
		if err := os.WriteFile(tmp, out.Bytes(), 0o600); err != nil {
			continue
		}
		_ = os.Chmod(tmp, 0o600)
		if err := os.Rename(tmp, filepath.Join(homeDir, dst)); err != nil {
			_ = os.Remove(tmp)
			continue
		}
		fmt.Printf("decrypted ftp config -> %s\n", filepath.Join(homeDir, dst))
	}
	return shared.ExitOK
}

func splitConf(p string) (string, string) {
	if i := strings.IndexByte(p, ':'); i >= 0 {
		return p[:i], p[i+1:]
	}
	return p, ""
}

func cmdTransform(args []string) int {
	confPath := ""
	iniPath := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--conf":
			if i+1 < len(args) {
				confPath = args[i+1]
				i++
			}
		case "--ini":
			if i+1 < len(args) {
				iniPath = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp transform option: %s\n", args[i])
			usage()
			return shared.ExitUsage
		}
	}
	if confPath == "" || iniPath == "" {
		fmt.Fprintln(os.Stderr, "error: transform requires --conf and --ini")
		usage()
		return shared.ExitUsage
	}
	remote, path, ini, err := Transform(confPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}
	if err := os.WriteFile(iniPath, ini, 0o600); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}
	_ = os.Chmod(iniPath, 0o600)
	fmt.Printf("remote=%s\npath=%s\n", remote, path)
	return shared.ExitOK
}

func cmdMount(args []string) int {
	configFile := ""
	mountPoint := ""
	remotePath := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--conf":
			if i+1 < len(args) {
				configFile = args[i+1]
				i++
			}
		case "--mount-point":
			if i+1 < len(args) {
				mountPoint = args[i+1]
				i++
			}
		case "--remote-path":
			if i+1 < len(args) {
				remotePath = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp mount option: %s\n", args[i])
			usage()
			return shared.ExitUsage
		}
	}
	if configFile == "" || mountPoint == "" {
		fmt.Fprintln(os.Stderr, "error: mount requires --conf and --mount-point")
		usage()
		return shared.ExitUsage
	}
	conf := filepath.Join(shared.Home(), configFile)
	if _, err := os.Stat(conf); err != nil {
		fmt.Fprintf(os.Stderr, "warn: ftp config not found at %s; nothing to mount\n", conf)
		return shared.ExitOK
	}

	tmpdir := filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "angst-ftp")
	_ = os.MkdirAll(tmpdir, 0o700)
	_ = os.Chmod(tmpdir, 0o700)
	f, err := os.CreateTemp(tmpdir, "ftp.*.conf")
	if err != nil {
		return shared.ExitError
	}
	tmpconf := f.Name()
	_ = f.Close()
	defer os.Remove(tmpconf)

	remote, path, ini, err := Transform(conf)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}
	if err := os.WriteFile(tmpconf, ini, 0o600); err != nil {
		return shared.ExitError
	}

	if remotePath != "" {
		path = remotePath
	}

	unmount(mountPoint)
	mountDir := filepath.Join(shared.Home(), mountPoint)
	_ = os.MkdirAll(mountDir, 0o755)

	rclone, err := exec.LookPath("rclone")
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: rclone not found in PATH")
		return shared.ExitError
	}
	argsList := []string{
		rclone, "mount", "--config", tmpconf, "--no-modtime", "--vfs-cache-mode", "off",
		remote + ":" + path, mountDir,
	}
	env := os.Environ()
	if err := syscall.Exec(rclone, argsList, env); err != nil {
		fmt.Fprintf(os.Stderr, "error: exec rclone: %v\n", err)
		return shared.ExitError
	}
	return shared.ExitOK
}

func cmdUnmount(args []string) int {
	mountPoint := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--mount-point":
			if i+1 < len(args) {
				mountPoint = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp unmount option: %s\n", args[i])
			usage()
			return shared.ExitUsage
		}
	}
	if mountPoint == "" {
		fmt.Fprintln(os.Stderr, "error: unmount requires --mount-point")
		usage()
		return shared.ExitUsage
	}
	unmount(mountPoint)
	return shared.ExitOK
}

func unmount(mountPoint string) {
	p := filepath.Join(shared.Home(), mountPoint)
	c1 := exec.Command("fusermount3", "-u", p)
	c1.Stdout = nil
	c1.Stderr = nil
	if err := c1.Run(); err == nil {
		return
	}
	c2 := exec.Command("fusermount", "-u", p)
	c2.Stdout = nil
	c2.Stderr = nil
	if err := c2.Run(); err == nil {
		return
	}
	c3 := exec.Command("fusermount3", "-uz", p)
	c3.Stdout = nil
	c3.Stderr = nil
	_ = c3.Run()
	c4 := exec.Command("fusermount", "-uz", p)
	c4.Stdout = nil
	c4.Stderr = nil
	_ = c4.Run()
}
