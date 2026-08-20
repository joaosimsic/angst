package vault

import (
	"archive/tar"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/shared"
)

func encryptDir(keyfile, recipient, path string, info os.FileInfo, force bool) int {
	if !info.IsDir() {
		fmt.Fprintf(os.Stderr, "error: --dir requires a directory\n")
		return shared.ExitError
	}

	ageFile := path + ".tar.age"

	if !force {
		if _, err := os.Stat(ageFile); err == nil {
			fmt.Fprintf(os.Stderr, "skip (exists): %s\n", ageFile)
			return shared.ExitOK
		}
	}

	tmpDir, err := os.MkdirTemp("", "vault-tar-*")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error creating temp dir: %v\n", err)
		return shared.ExitError
	}
	defer os.RemoveAll(tmpDir)

	tmpTar := filepath.Join(tmpDir, "out.tar")

	if err := tarDirectory(path, tmpTar); err != nil {
		fmt.Fprintf(os.Stderr, "error creating tarball: %v\n", err)
		return shared.ExitError
	}

	if err := shared.AgeEncrypt(keyfile, recipient, tmpTar, ageFile); err != nil {
		fmt.Fprintf(os.Stderr, "error encrypting tarball: %v\n", err)
		return shared.ExitError
	}

	if err := os.Chmod(ageFile, 0600); err != nil {
		fmt.Fprintf(os.Stderr, "error chmod %s: %v\n", ageFile, err)
	}

	os.RemoveAll(path)

	fmt.Printf("%s/ -> %s\n", path, ageFile)
	return shared.ExitOK
}

func decryptDir(keyfile, path string, info os.FileInfo) int {
	if info.IsDir() {
		fmt.Fprintf(os.Stderr, "error: --dir requires a .tar.age file\n")
		return shared.ExitError
	}

	if !strings.HasSuffix(path, ".tar.age") {
		fmt.Fprintf(os.Stderr, "error: expected a .tar.age file with --dir\n")
		return shared.ExitError
	}

	destDir := strings.TrimSuffix(path, ".tar.age")

	if err := DecryptTarball(keyfile, path, destDir); err != nil {
		fmt.Fprintf(os.Stderr, "error decrypting tarball: %v\n", err)
		return shared.ExitError
	}

	os.Remove(path)

	fmt.Printf("%s -> %s/\n", path, destDir)
	return shared.ExitOK
}

// DecryptTarball decrypts an age-encrypted tarball (src) and extracts its
// contents into destDir. It is used both by the CLI (decrypt --dir) and by
// callers that need to extract into an arbitrary directory (e.g. boot, which
// extracts into the working store rather than the read-only nix store).
func DecryptTarball(keyfile, src, destDir string) error {
	tmpDir, err := os.MkdirTemp("", "vault-untar-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	tmpTar := filepath.Join(tmpDir, "out.tar")

	if err := shared.AgeDecrypt(keyfile, src, tmpTar); err != nil {
		return err
	}

	return untarDirectory(tmpTar, destDir)
}

func tarDirectory(srcDir, outTar string) error {
	tarFile, err := os.Create(outTar)
	if err != nil {
		return err
	}
	defer tarFile.Close()

	tw := tar.NewWriter(tarFile)
	defer tw.Close()

	return filepath.Walk(srcDir, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		rel, err := filepath.Rel(srcDir, p)
		if err != nil {
			return err
		}

		header, err := tar.FileInfoHeader(fi, "")
		if err != nil {
			return err
		}
		header.Name = filepath.ToSlash(rel)

		if fi.IsDir() {
			header.Name += "/"
		}

		if err := tw.WriteHeader(header); err != nil {
			return err
		}

		if fi.IsDir() {
			return nil
		}

		f, err := os.Open(p)
		if err != nil {
			return err
		}
		defer f.Close()

		_, err = io.Copy(tw, f)
		return err
	})
}

func untarDirectory(tarFile, destDir string) error {
	f, err := os.Open(tarFile)
	if err != nil {
		return err
	}
	defer f.Close()

	tr := tar.NewReader(f)

	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		target := filepath.Join(destDir, filepath.FromSlash(header.Name))

		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0700); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(target), 0700); err != nil {
				return err
			}
			f, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(header.Mode))
			if err != nil {
				return err
			}
			if _, err := io.Copy(f, tr); err != nil {
				f.Close()
				return err
			}
			f.Close()
		}
	}

	return nil
}
