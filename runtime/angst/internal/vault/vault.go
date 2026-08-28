package vault

import (
	"fmt"
	"os"

	"angst/internal/scope"
	"angst/internal/shared"
)

type options struct {
	path     string
	dirMode  bool
	force    bool
	delete   bool
	noDelete bool
	sc       scope.Scope
}

func parseArgs(args []string) (string, options, error) {
	var opts options
	var positional []string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dir":
			opts.dirMode = true
		case "--force":
			opts.force = true
		case "--delete":
			opts.delete = true
		case "--no-delete":
			opts.noDelete = true
		case "--scope":
			i++
			if i >= len(args) {
				return "", opts, fmt.Errorf("--scope requires a value")
			}
			switch args[i] {
			case "personal":
				opts.sc = scope.Personal
			case "work":
				opts.sc = scope.Work
			default:
				return "", opts, fmt.Errorf("unknown scope: %s (use personal or work)", args[i])
			}
		case "-h", "--help":
			return "", opts, fmt.Errorf("help")
		default:
			positional = append(positional, args[i])
		}
	}

	if len(positional) < 1 {
		return "", opts, fmt.Errorf("path argument required")
	}
	opts.path = positional[0]

	opts.delete = !opts.noDelete

	return positional[0], opts, nil
}

func Run(args []string) int {
	cmdName := ""
	if len(args) > 0 {
		cmdName = args[0]
		args = args[1:]
	}

	switch cmdName {
	case "encrypt":
		return cmdEncrypt(args)
	case "decrypt":
		return cmdDecrypt(args)
	case "status":
		return cmdStatus(args)
	case "", "-h", "--help":
		usage()
		return shared.ExitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown vault command: %s\n", cmdName)
		usage()
		return shared.ExitUsage
	}
}

func cmdEncrypt(args []string) int {
	_, opts, err := parseArgs(args)
	if err != nil {
		if err.Error() == "help" {
			usageEncrypt()
			return shared.ExitOK
		}
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitUsage
	}

	keyfile := scope.AgeKeyfile(opts.sc, scope.EnvOverride)
	recipient, err := scope.RecipientFor(opts.sc, scope.EnvOverride)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error resolving recipient: %v\n", err)
		return shared.ExitError
	}

	info, err := os.Stat(opts.path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}

	if opts.dirMode {
		return encryptDir(keyfile, recipient, opts.path, info, opts.force)
	}
	return encryptPath(keyfile, recipient, opts.path, info, opts.force, opts.delete)
}

func cmdDecrypt(args []string) int {
	_, opts, err := parseArgs(args)
	if err != nil {
		if err.Error() == "help" {
			usageDecrypt()
			return shared.ExitOK
		}
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitUsage
	}

	keyfile := scope.AgeKeyfile(opts.sc, scope.EnvOverride)

	info, err := os.Stat(opts.path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitError
	}

	if opts.dirMode {
		return decryptDir(keyfile, opts.path, info)
	}
	return decryptPath(keyfile, opts.path, info)
}

func cmdStatus(args []string) int {
	_, opts, err := parseArgs(args)
	if err != nil {
		if err.Error() == "help" {
			usageStatus()
			return shared.ExitOK
		}
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return shared.ExitUsage
	}

	return statusPath(opts.path)
}

func usage() {
	fmt.Print(`Usage:
  angst vault encrypt <path> [flags]
  angst vault decrypt <path> [flags]
  angst vault status <path>

Flags:
  --scope personal|work   Age key scope (default: personal)
  --dir                   Directory mode: tar + encrypt the whole directory
  --force                 Overwrite existing .age files
  --delete                Delete source after encryption (file mode default: delete)
  --no-delete             Keep source after encryption (file mode only)

Examples:
  angst vault encrypt secrets/              # encrypt files in-place
  angst vault encrypt projects/ --dir       # tar + encrypt entire directory
  angst vault decrypt secrets/              # decrypt all .age files
  angst vault decrypt projects.tar.age --dir  # decrypt + untar
  angst vault status .                      # show encryption status
`)
}

func usageEncrypt() {
	fmt.Print(`Usage:
  angst vault encrypt <path> [flags]

Encrypt files or directories using age.

File mode (default):
  Encrypts each file in-place: foo.yaml -> foo.yaml.age
  Directories are walked recursively; .age files are skipped.

Dir mode (--dir):
  tars the directory, encrypts the tarball: mydir/ -> mydir.tar.age
  The original directory is removed after encryption.

Flags:
  --scope personal|work   Age key scope (default: personal)
  --dir                   Directory mode (tar + encrypt)
  --force                 Overwrite existing .age files
  --delete                Delete source after encryption (file mode default: delete)
  --no-delete             Keep source after encryption (file mode only)
`)
}

func usageDecrypt() {
	fmt.Print(`Usage:
  angst vault decrypt <path> [flags]

Decrypt age-encrypted files or directories.

File mode (default):
  Decrypts .age files: foo.yaml.age -> foo.yaml
  Walks directories recursively to find .age files.

Dir mode (--dir):
  Decrypts the tarball, extracts the directory: mydir.tar.age -> mydir/
  Removes the .tar.age after extraction.

Flags:
  --scope personal|work   Age key scope (default: personal)
  --dir                   Directory mode (decrypt + untar)
`)
}

func usageStatus() {
	fmt.Print(`Usage:
  angst vault status <path>

Show encryption status for files and directories.
Reports which files are encrypted (.age) and which are plaintext.
`)
}
