package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/joaosimsic/angst/runtime/logger"
)

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	hmArgs := buildHmArgs(args)

	stateDir := logger.StateDir()
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not create state dir %s: %v\n", stateDir, err)
		return 1
	}

	stamp := logger.Stamp()
	logPath := logger.SwitchLogPath(stamp)
	exitFile := logger.ExitPath(stamp)
	latest := logger.LatestPath()
	user := logger.User()
	host := logger.Hostname()
	cmdline := "home-manager " + strings.Join(hmArgs, " ")

	fmt.Printf("%s── angst hm-switch ──%s %s%s  %s@%s%s\n", logger.GreenBold(), logger.Reset(), logger.Green(), stamp, user, host, logger.Reset())
	fmt.Printf("%s%s%s\n", logger.DarkGray(), cmdline, logger.Reset())

	header := fmt.Sprintf("── angst hm-switch ── %s  %s@%s\ncmd: %s\n", stamp, user, host, cmdline)
	if err := os.WriteFile(logPath, []byte(header), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not write log %s: %v\n", logPath, err)
		return 1
	}
	logFile, err := os.OpenFile(logPath, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: could not open log %s: %v\n", logPath, err)
		return 1
	}
	defer logFile.Close()

	bashScript := `home-manager "$@" 2>&1; echo $? > "$0"`
	bashArgs := append([]string{"-c", bashScript, exitFile}, hmArgs...)
	cmd := exec.Command("bash", bashArgs...)
	cmd.Env = os.Environ()
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: could not pipe home-manager: %v\n", err)
		return 1
	}
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not start home-manager: %v\n", err)
		return 1
	}

	var errors, warns, steps int

	reader := bufio.NewScanner(stdout)
	buf := make([]byte, 0, 64*1024)
	reader.Buffer(buf, 10*1024*1024)
	for reader.Scan() {
		line := reader.Text()
		lvl := logger.LevelOf(line)
		switch lvl {
		case logger.ERROR:
			errors++
		case logger.WARN:
			warns++
		case logger.STEP:
			steps++
		}
		ts := logger.Timestamp()
		badge := logger.ColorBadge(lvl)
		fmt.Printf("%s[%s]%s %s %s\n", badge, lvl, logger.Reset(), ts, line)
		fmt.Fprintf(logFile, "[%s] %s %s\n", lvl, ts, line)
	}
	if err := reader.Err(); err != nil && err != io.EOF {
		fmt.Fprintf(os.Stderr, "error reading home-manager output: %v\n", err)
	}

	if err := cmd.Wait(); err != nil {
		_ = err
	}

	exitCode := 1
	data, err := os.ReadFile(exitFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: could not read exit code %s: %v\n", exitFile, err)
	} else {
		s := strings.TrimSpace(string(data))
		var parsed int
		if _, err := fmt.Sscanf(s, "%d", &parsed); err == nil {
			exitCode = parsed
		}
	}
	_ = os.Remove(exitFile)

	fmt.Printf("%s── summary ──  exit %d  errors %d  warnings %d  steps %d\n", logger.Reset(), exitCode, errors, warns, steps)
	fmt.Printf("log: %s\n", logPath)

	if err := copyFile(logPath, latest); err != nil {
		fmt.Fprintf(os.Stderr, "warn: could not update latest.log: %v\n", err)
	}

	return exitCode
}

func buildHmArgs(args []string) []string {
	if len(args) == 0 {
		return []string{"switch", "--flake", "."}
	}
	if strings.HasPrefix(args[0], "-") {
		return append([]string{"switch"}, args...)
	}
	return args
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}
