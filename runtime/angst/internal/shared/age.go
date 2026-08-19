package shared

import "os/exec"

func AgeDecrypt(keyfile, in, out string) error {
	c := exec.Command("age", "-d", "-i", keyfile, "-o", out, in)
	c.Stderr = nil
	return c.Run()
}
