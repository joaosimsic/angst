package analyze

import (
	"regexp"
	"strings"
	"time"
)


func gitChurn() map[string]int {
	out := gitLog([]string{"*.nix", "*.sh", "*.rs"}, "1 year ago")
	churn := map[string]int{}
	for _, line := range out {
		if line == "" {
			continue
		}
		if line[0] >= '0' && line[0] <= '9' || strings.HasPrefix(line, "commit ") {
			continue
		}
		churn[line]++
	}
	return churn
}

var commitHashRe = regexp.MustCompile(`^[0-9a-f]{7,40}$`)



func gitStability() (churn map[string]int, fileLastDate map[string]string) {
	churn = map[string]int{}
	fileLastDate = map[string]string{}

	rc, out2, _ := runExec([]string{
		"git", "log", "--oneline", "--since=2 years ago",
		"--format=%H %ai", "--", "*.nix",
	}, 30*time.Second)
	dateByCommit := map[string]string{}
	if rc == 0 {
		for _, line := range strings.Split(out2, "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			parts := strings.SplitN(line, " ", 2)
			if len(parts) == 2 {
				dateByCommit[parts[0]] = parts[1]
			}
		}
	}

	rc, out3, _ := runExec([]string{
		"git", "log", "--oneline", "--since=2 years ago",
		"--format=%H", "--name-only", "--", "*.nix",
	}, 30*time.Second)
	currentHash := ""
	if rc == 0 {
		for _, line := range strings.Split(out3, "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			if commitHashRe.MatchString(line) {
				currentHash = line
				continue
			}
			churn[line]++
			if currentHash != "" && fileLastDate[line] == "" {
				if d, ok := dateByCommit[currentHash]; ok {
					fileLastDate[line] = d
				}
			}
		}
	}
	return churn, fileLastDate
}
