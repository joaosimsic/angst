package shared

import "os"

func Home() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	hd, _ := os.UserHomeDir()
	return hd
}
