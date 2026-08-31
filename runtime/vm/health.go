package vm

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type HealthReport struct {
	QemuRunning   bool
	QemuPID       int
	HostFwd       *bool
	PortListening *bool
	SSHReachable  *bool
}

func (h HealthReport) String() string {
	var b strings.Builder
	check := func(ok bool, label, detail string) {
		if ok {
			b.WriteString(fmt.Sprintf("✓ %s  %s\n", label, detail))
		} else {
			b.WriteString(fmt.Sprintf("✗ %s  %s\n", label, detail))
		}
	}

	qpid := "no process found"
	if h.QemuPID != 0 {
		qpid = fmt.Sprintf("(PID %d)", h.QemuPID)
	}
	check(h.QemuRunning, "QEMU running", qpid)

	if h.HostFwd != nil {
		if *h.HostFwd {
			check(true, "SSH port forwarding", "hostfwd present")
		} else {
			check(false, "SSH port forwarding", "hostfwd MISSING")
		}
	}
	if h.PortListening != nil {
		if *h.PortListening {
			check(true, "Port 2222 listening", "0.0.0.0:2222")
		} else {
			check(false, "Port 2222 listening", "not listening")
		}
	}
	if h.SSHReachable != nil {
		if *h.SSHReachable {
			check(true, "SSH reachable", "exec true ok")
		} else {
			check(false, "SSH reachable", "connection refused")
		}
	}
	return b.String()
}

func anyQemuRunning() bool {
	c := exec.Command("pgrep", "-f", "qemu-system")
	c.Stdout = nil
	c.Stderr = nil
	return c.Run() == nil
}

func qemuPID() (int, bool) {
	out, err := exec.Command("pgrep", "-f", "qemu-system.*qcow2").Output()
	if err != nil {
		return 0, false
	}
	s := strings.TrimSpace(string(out))
	if s == "" {
		return 0, false
	}
	pid, err := strconv.Atoi(s)
	if err != nil {
		return 0, false
	}
	return pid, true
}

func pidHasHostfwd(pid int) bool {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/cmdline", pid))
	if err != nil {
		return false
	}
	return strings.Contains(string(b), "hostfwd")
}

func portListens(port uint16) bool {
	hex := fmt.Sprintf("%04X", port)
	b, err := os.ReadFile("/proc/net/tcp")
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.Contains(line, hex) {
			return true
		}
	}
	return false
}

func checkHealth(sshExec func(string) (int, string, string)) HealthReport {
	var r HealthReport
	r.QemuRunning = anyQemuRunning()
	if r.QemuRunning {
		if pid, ok := qemuPID(); ok {
			r.QemuPID = pid
			hf := pidHasHostfwd(pid)
			r.HostFwd = &hf
		}
		pl := portListens(2222)
		r.PortListening = &pl
		if pl {
			code, _, _ := sshExec("true")
			ok := code == 0
			r.SSHReachable = &ok
		}
	}
	return r
}

func boolPtr(b bool) *bool { return &b }
