package analyze

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type memResult struct {
	Attr   string  `json:"attr"`
	Rc     int     `json:"rc"`
	MaxRSS int64   `json:"maxRSSKiB"`
	Wall   float64 `json:"wallSeconds"`
	Err    string  `json:"err,omitempty"`
}

var rssRe = regexp.MustCompile(`Maximum resident set size \(kbytes\):\s*(\d+)`)

func runWithMem(args []string, timeout time.Duration) (int, string, string, int64, float64) {
	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	var mem int64 = -1
	var rc int
	var out, errb string

	if hasCmd("time") {
		full := append([]string{"-v"}, args...)
		bin := "time"
		if p, err := exec.LookPath("/usr/bin/time"); err == nil {
			bin = p
		} else if p, err := exec.LookPath("/bin/time"); err == nil {
			bin = p
		}
		cmd := exec.CommandContext(ctx, bin, full...)
		cmd.Dir = repoRoot()
		var stdout, stderr bytes.Buffer
		cmd.Stdout = &stdout
		cmd.Stderr = &stderr
		err := cmd.Run()
		if err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				rc = ee.ExitCode()
			} else {
				rc = -1
			}
		}
		out = stdout.String()
		errStr := stderr.String()
		if m := rssRe.FindStringSubmatch(errStr); m != nil {
			if v, err := strconv.ParseInt(m[1], 10, 64); err == nil {
				mem = v
			}
		}
		errb = strings.TrimSpace(rssRe.ReplaceAllString(errStr, ""))
		if rc == 0 {
			errb = ""
		} else if errb == "" {
			errb = strings.TrimSpace(errStr)
		}
	} else {
		rc, out, errb = runExec(args, timeout)
	}

	elapsed := time.Since(start).Seconds()
	if mem < 0 {
		if v := rssFromNixStats(out + "\n" + errb); v > 0 {
			mem = v
		}
	}
	return rc, out, errb, mem, elapsed
}

func rssFromNixStats(combined string) int64 {
	re := regexp.MustCompile(`(?m)peak heap.*?:\s*([\d\.]+)\s*MiB`)
	if m := re.FindStringSubmatch(combined); m != nil {
		if f, err := strconv.ParseFloat(m[1], 64); err == nil {
			return int64(f * 1024)
		}
	}
	return -1
}

func formatMiB(kib int64) string {
	if kib < 0 {
		return "—"
	}
	mib := float64(kib) / 1024.0
	if mib >= 1024 {
		return fmt.Sprintf("%.1f GiB", mib/1024.0)
	}
	return fmt.Sprintf("%d MiB", int(mib+0.5))
}

func formatMemTable(rows []memResult) string {
	headers := []string{"Attr", "maxRSS", "wall", "result"}
	var tRows [][]any
	for _, r := range rows {
		status := "✓"
		if r.Rc != 0 {
			status = "✗"
		}
		extra := ""
		if r.Rc != 0 && r.Err != "" {
			short := strings.TrimSpace(r.Err)
			if len(short) > 120 {
				short = short[:120]
			}
			extra = strings.ReplaceAll(short, "\n", " ")
			if extra != "" {
				status += " " + extra
			}
		}
		tRows = append(tRows, []any{
			fmt.Sprintf("`%s`", r.Attr),
			formatMiB(r.MaxRSS),
			fmt.Sprintf("%.1fs", r.Wall),
			status,
		})
	}
	return mdTable(headers, tRows)
}

func gateStatus(kib int64, limitMiB int) string {
	if kib < 0 {
		return "—"
	}
	mib := kib / 1024
	if mib <= int64(limitMiB) {
		return "✓"
	}
	return fmt.Sprintf("✗ >%d MiB", limitMiB)
}
