package main

import (
	"fmt"
	"os"

	"angst/internal/boot"
	"angst/internal/ftp"
	"angst/internal/projects"
	"angst/internal/render"
	"angst/internal/sshkey"
	"angst/internal/analyze"
	"angst/internal/shell"
	"angst/internal/system"
	"angst/internal/vault"
	"angst/internal/vm"
)

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	name := ""
	if len(args) > 0 {
		name = args[0]
		args = args[1:]
	}
	switch name {
	case "render":
		return render.Render(args)
	case "watch":
		return render.Watch(args)
	case "bootstrap-master-password":
		return boot.BootstrapMasterPassword(args)
	case "set-password-hash":
		return boot.SetPasswordHash(args)
	case "projects":
		return projects.Run(args)
	case "ssh-key":
		return sshkey.Run(args)
	case "login-shell":
		return system.LoginShell(args)
	case "ssh-add-keys":
		return system.SSHAddKeys(args)
	case "provision-ssh-key":
		return system.ProvisionSSHKey(args)
	case "provision-app-secret":
		return system.ProvisionAppSecret(args)
	case "ftp":
		return ftp.Run(args)
	case "vault":
		return vault.Run(args)
	case "vm":
		return vm.Run(args)
	case "shell":
		return shell.Run(args)
	case "analyze":
		return analyze.Run(args)
	case "", "-h", "--help":
		usage()
		return 0
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", name)
		usage()
		return 2
	}
}

func usage() {
	fmt.Print(`Usage:
  angst bootstrap-master-password [--host HOST] [--scope personal|work]
  angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
  angst watch  [--repo PATH] [--host HOST] [--theme THEME]
  angst projects <add|sync|status|capture|edit-env|import|export|rm> ...
  angst vault <encrypt|decrypt|status> ...
  angst ssh-key <generate|verify> --scope personal|work
  angst login-shell --shell NAME --home DIR --user USER
  angst ssh-add-keys KEY...
  angst provision-ssh-key --user USER --home DIR --secrets-dir DIR [--scopes work[,personal]]
  angst provision-app-secret --secrets-dir DIR --slug NAME [--slug NAME ...] [--scopes work[,personal]] [--home DIR]
  angst set-password-hash --username USER --age-path FILE --age-key FILE
  angst ftp <decrypt|mount|unmount|transform> ...
  angst vm <home-manager-upgrade|ephemeral-ssh|age-key|nixos-switch|home-switch> ...
  angst shell <dev|safe>
  angst analyze [--no-eval-cost] [--no-graph] [-o FILE]
`)
}
