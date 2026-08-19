package ftp

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"angst/internal/scope"
)

const (
	exitUsage = 2
	exitError = 1
	exitOK    = 0
)

type kv struct {
	key string
	val interface{}
}

type orderedMap []kv

func (m orderedMap) get(k string) (interface{}, bool) {
	for _, e := range m {
		if e.key == k {
			return e.val, true
		}
	}
	return nil, false
}

func (m orderedMap) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, e := range m {
		if i > 0 {
			b.WriteByte(',')
		}
		kb, _ := json.Marshal(e.key)
		vb, _ := json.Marshal(e.val)
		b.Write(kb)
		b.WriteByte(':')
		b.Write(vb)
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}

func home() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	hd, _ := os.UserHomeDir()
	return hd
}

// Run dispatches `angst ftp <cmd>` and returns the process exit code.
func Run(args []string) int {
	if len(args) == 0 {
		usage()
		return exitUsage
	}
	cmdName := args[0]
	args = args[1:]
	switch cmdName {
	case "decrypt":
		return cmdDecrypt(args)
	case "transform":
		return cmdTransform(args)
	case "mount":
		return cmdMount(args)
	case "unmount":
		return cmdUnmount(args)
	case "-h", "--help":
		usage()
		return exitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown ftp command: %s\n", cmdName)
		usage()
		return exitUsage
	}
}

func usage() {
	fmt.Print(`Usage:
  angst ftp decrypt --home DIR --conf SOURCE:DEST [...]
  angst ftp transform --conf FILE --ini FILE
  angst ftp mount --conf FILE --mount-point DIR [--remote-path PATH]
  angst ftp unmount --mount-point DIR
`)
}

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
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp decrypt option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}

	workKey := scope.AgeKeyfile(scope.Work, scope.EnvOverride)
	if _, err := os.Stat(workKey); err != nil {
		fmt.Fprintf(os.Stderr, "warn: work age key not found at %s; cannot decrypt ftp configs\n", workKey)
		return exitOK
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
	return exitOK
}

func splitConf(p string) (string, string) {
	if i := strings.IndexByte(p, ':'); i >= 0 {
		return p[:i], p[i+1:]
	}
	return p, ""
}

func decodeValue(d *json.Decoder) (interface{}, error) {
	tok, err := d.Token()
	if err != nil {
		return nil, err
	}
	return buildValue(d, tok)
}

func buildValue(d *json.Decoder, tok json.Token) (interface{}, error) {
	switch t := tok.(type) {
	case json.Delim:
		switch t {
		case '{':
			m := orderedMap{}
			for d.More() {
				kt, err := d.Token()
				if err != nil {
					return nil, err
				}
				key, ok := kt.(string)
				if !ok {
					return nil, fmt.Errorf("unexpected object key token %v", kt)
				}
				v, err := decodeValue(d)
				if err != nil {
					return nil, err
				}
				m = append(m, kv{key, v})
			}
			if _, err := d.Token(); err != nil {
				return nil, err
			}
			return m, nil
		case '[':
			arr := []interface{}{}
			for d.More() {
				v, err := decodeValue(d)
				if err != nil {
					return nil, err
				}
				arr = append(arr, v)
			}
			if _, err := d.Token(); err != nil {
				return nil, err
			}
			return arr, nil
		}
	default:
		return tok, nil
	}
	return nil, fmt.Errorf("unexpected token %v", tok)
}

func jqTostring(v interface{}) string {
	switch t := v.(type) {
	case string:
		return t
	case json.Number:
		return t.String()
	case bool:
		if t {
			return "true"
		}
		return "false"
	case nil:
		return "null"
	default:
		b, err := json.Marshal(v)
		if err != nil {
			return ""
		}
		return string(b)
	}
}

// Transform renders an rclone INI from a validated .conf JSON and returns the
// remote, path, and ini bytes.
func Transform(confPath string) (remote, path string, ini []byte, err error) {
	f, err := os.Open(confPath)
	if err != nil {
		return "", "", nil, err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	d.UseNumber()
	val, err := decodeValue(d)
	if err != nil {
		return "", "", nil, err
	}
	obj, ok := val.(orderedMap)
	if !ok {
		return "", "", nil, fmt.Errorf("%s: expected a top-level JSON object", confPath)
	}
	if r, ok := obj.get("remote"); ok {
		if s, ok := r.(string); ok {
			remote = s
		}
	}
	pv, ok := obj.get("path")
	if ok && pv != nil {
		path = jqTostring(pv)
	}
	if path == "" {
		path = "/"
	}
	var b strings.Builder
	b.WriteString("[" + remote + "]\n")
	if cfg, ok := obj.get("config"); ok {
		if cm, ok := cfg.(orderedMap); ok {
			for _, e := range cm {
				b.WriteString(e.key + " = " + jqTostring(e.val) + "\n")
			}
		}
	}
	return remote, path, []byte(b.String()), nil
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
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp transform option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}
	if confPath == "" || iniPath == "" {
		fmt.Fprintln(os.Stderr, "error: transform requires --conf and --ini")
		usage()
		return exitUsage
	}
	remote, path, ini, err := Transform(confPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return exitError
	}
	if err := os.WriteFile(iniPath, ini, 0o600); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return exitError
	}
	_ = os.Chmod(iniPath, 0o600)
	fmt.Printf("remote=%s\npath=%s\n", remote, path)
	return exitOK
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
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp mount option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}
	if configFile == "" || mountPoint == "" {
		fmt.Fprintln(os.Stderr, "error: mount requires --conf and --mount-point")
		usage()
		return exitUsage
	}
	conf := filepath.Join(home(), configFile)
	if _, err := os.Stat(conf); err != nil {
		fmt.Fprintf(os.Stderr, "warn: ftp config not found at %s; nothing to mount\n", conf)
		return exitOK
	}

	tmpdir := filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "angst-ftp")
	_ = os.MkdirAll(tmpdir, 0o700)
	_ = os.Chmod(tmpdir, 0o700)
	f, err := os.CreateTemp(tmpdir, "ftp.*.conf")
	if err != nil {
		return exitError
	}
	tmpconf := f.Name()
	_ = f.Close()
	defer os.Remove(tmpconf)

	remote, path, ini, err := Transform(conf)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return exitError
	}
	if err := os.WriteFile(tmpconf, ini, 0o600); err != nil {
		return exitError
	}

	if remotePath != "" {
		path = remotePath
	}

	unmount(mountPoint)
	mountDir := filepath.Join(home(), mountPoint)
	_ = os.MkdirAll(mountDir, 0o755)

	rclone, err := exec.LookPath("rclone")
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: rclone not found in PATH")
		return exitError
	}
	argsList := []string{
		rclone, "mount", "--config", tmpconf, "--no-modtime", "--vfs-cache-mode", "off",
		remote + ":" + path, mountDir,
	}
	env := os.Environ()
	if err := syscall.Exec(rclone, argsList, env); err != nil {
		fmt.Fprintf(os.Stderr, "error: exec rclone: %v\n", err)
		return exitError
	}
	return exitOK
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
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ftp unmount option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}
	if mountPoint == "" {
		fmt.Fprintln(os.Stderr, "error: unmount requires --mount-point")
		usage()
		return exitUsage
	}
	unmount(mountPoint)
	return exitOK
}

func unmount(mountPoint string) {
	p := filepath.Join(home(), mountPoint)
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
	// Lazy unmount as fallback for stale mounts after home-manager switch
	c3 := exec.Command("fusermount3", "-uz", p)
	c3.Stdout = nil
	c3.Stderr = nil
	_ = c3.Run()
	c4 := exec.Command("fusermount", "-uz", p)
	c4.Stdout = nil
	c4.Stderr = nil
	_ = c4.Run()
}
