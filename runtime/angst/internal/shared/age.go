package shared

import (
	"fmt"
	"os/exec"
	"strings"
)

func AgeEncrypt(keyfile, recipient, in, out string) error {
	c := exec.Command("age", "-r", recipient, "-o", out, in)
	c.Env = append(c.Environ(), "SOPS_AGE_KEY_FILE="+keyfile)
	if b, err := c.CombinedOutput(); err != nil {
		return fmt.Errorf("age encrypt failed: %w: %s", err, strings.TrimSpace(string(b)))
	}
	return nil
}

func AgeDecrypt(keyfile, in, out string) error {
	c := exec.Command("age", "-d", "-i", keyfile, "-o", out, in)
	if b, err := c.CombinedOutput(); err != nil {
		return fmt.Errorf("age decrypt failed: %w: %s", err, strings.TrimSpace(string(b)))
	}
	return nil
}

func AgeRecipient(keyfile string) (string, error) {
	out, err := exec.Command("age-keygen", "-y", keyfile).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}
