package system

import (
	"os"
	"strings"

	"angst/internal/cmd"
	"angst/internal/shared"
)

func SSHAddKeys(args []string) int {
	for _, key := range args {
		if _, err := os.Stat(key); err != nil {
			continue
		}
		lf, err := cmd.Output("ssh-keygen", "-lf", key)
		if err != nil {
			continue
		}
		fields := strings.Fields(lf)
		if len(fields) < 2 {
			continue
		}
		fp := fields[1]
		added, err := cmd.Output("ssh-add", "-l")
		if err == nil && strings.Contains(added, fp) {
			continue
		}
		_ = quietRun("ssh-add", key)
	}
	return shared.ExitOK
}
