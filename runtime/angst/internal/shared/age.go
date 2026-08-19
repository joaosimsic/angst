package shared

import (
	"os/exec"
	"strings"
)

func AgeEncrypt(keyfile, recipient, in, out string) error {
	c := exec.Command("age", "-r", recipient, "-o", out, in)
	c.Env = append(c.Environ(), "SOPS_AGE_KEY_FILE="+keyfile)
	c.Stderr = nil
	return c.Run()
}

func AgeDecrypt(keyfile, in, out string) error {
	c := exec.Command("age", "-d", "-i", keyfile, "-o", out, in)
	c.Stderr = nil
	return c.Run()
}

func AgeRecipient(keyfile string) (string, error) {
	out, err := exec.Command("age-keygen", "-y", keyfile).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}
