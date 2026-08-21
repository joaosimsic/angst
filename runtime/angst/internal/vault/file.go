package vault

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/shared"
)

func encryptPath(keyfile, recipient, path string, info os.FileInfo, force, delete bool) int {
	if !info.IsDir() {
		return encryptSingleFile(keyfile, recipient, path, force, delete)
	}

	encrypted, skipped := 0, 0
	err := filepath.Walk(path, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if fi.IsDir() {
			return nil
		}
		if strings.HasSuffix(p, ".age") {
			skipped++
			return nil
		}
		switch encryptSingleFile(keyfile, recipient, p, force, delete) {
		case shared.ExitOK:
			encrypted++
		case shared.ExitError:
			return fmt.Errorf("failed to encrypt %s", p)
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}
	fmt.Printf("encrypted: %d, skipped: %d\n", encrypted, skipped)
	return shared.ExitOK
}

func encryptSingleFile(keyfile, recipient, path string, force, delete bool) int {
	out := path + ".age"
	if !force {
		if _, err := os.Stat(out); err == nil {
			fmt.Fprintf(os.Stderr, "skip (exists): %s\n", out)
			return shared.ExitOK
		}
	}

	if err := shared.AgeEncrypt(keyfile, recipient, path, out); err != nil {
		fmt.Fprintf(os.Stderr, "error encrypting %s: %v\n", path, err)
		return shared.ExitError
	}

	if err := os.Chmod(out, 0600); err != nil {
		fmt.Fprintf(os.Stderr, "error chmod %s: %v\n", out, err)
	}

	if delete {
		os.Remove(path)
	}

	fmt.Printf("%s -> %s\n", path, out)
	return shared.ExitOK
}

func decryptPath(keyfile, path string, info os.FileInfo) int {
	if info.IsDir() {
		return decryptDirFiles(keyfile, path)
	}
	return decryptSingleFile(keyfile, path)
}

func decryptSingleFile(keyfile, path string) int {
	if !strings.HasSuffix(path, ".age") {
		fmt.Fprintf(os.Stderr, "skip (not .age): %s\n", path)
		return shared.ExitOK
	}

	out := strings.TrimSuffix(path, ".age")
	if err := shared.AgeDecrypt(keyfile, path, out); err != nil {
		fmt.Fprintf(os.Stderr, "error decrypting %s: %v\n", path, err)
		return shared.ExitError
	}

	if err := os.Chmod(out, 0600); err != nil {
		fmt.Fprintf(os.Stderr, "error chmod %s: %v\n", out, err)
	}

	os.Remove(path)
	fmt.Printf("%s -> %s\n", path, out)
	return shared.ExitOK
}

func decryptDirFiles(keyfile, dir string) int {
	decrypted, skipped := 0, 0
	err := filepath.Walk(dir, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if fi.IsDir() {
			return nil
		}
		if !strings.HasSuffix(p, ".age") {
			skipped++
			return nil
		}
		switch decryptSingleFile(keyfile, p) {
		case shared.ExitOK:
			decrypted++
		case shared.ExitError:
			return fmt.Errorf("failed to decrypt %s", p)
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}
	fmt.Printf("decrypted: %d, skipped: %d\n", decrypted, skipped)
	return shared.ExitOK
}

func statusPath(path string) int {
	info, err := os.Stat(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}

	if !info.IsDir() {
		return printFileStatus(path)
	}

	encrypted, plaintext := 0, 0
	err = filepath.Walk(path, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if fi.IsDir() {
			return nil
		}
		if strings.HasSuffix(p, ".age") {
			encrypted++
		} else {
			plaintext++
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}
	fmt.Printf("encrypted: %d, plaintext: %d\n", encrypted, plaintext)
	return shared.ExitOK
}

func printFileStatus(path string) int {
	if strings.HasSuffix(path, ".age") {
		fmt.Printf("%s: encrypted\n", path)
	} else {
		fmt.Printf("%s: plaintext\n", path)
	}
	return shared.ExitOK
}
