package cmd

import (
	"bytes"
	"os"
	"os/exec"
)

func Run(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

func RunDir(dir string, env []string, name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Dir = dir
	c.Env = append(os.Environ(), env...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

func Output(name string, args ...string) (string, error) {
	c := exec.Command(name, args...)
	c.Stderr = os.Stderr
	var out bytes.Buffer
	c.Stdout = &out
	if err := c.Run(); err != nil {
		return "", err
	}
	return trimRightNewlines(out.Bytes()), nil
}

func OutputRaw(name string, args ...string) ([]byte, error) {
	c := exec.Command(name, args...)
	c.Stderr = os.Stderr
	var out bytes.Buffer
	c.Stdout = &out
	if err := c.Run(); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func Feed(data []byte, name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdin = bytes.NewReader(data)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

func FeedDir(dir string, data []byte, name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Dir = dir
	c.Stdin = bytes.NewReader(data)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

func trimRightNewlines(b []byte) string {
	return string(bytes.TrimRight(b, "\n"))
}
