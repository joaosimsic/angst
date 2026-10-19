{
  pkgs,
}:
{ defaultVmHost }:
pkgs.writeText "shell-dev-hook" ''
  export VM_SSH_PORT=2222
  export NIX_DEFAULT_TARGET_HOST=${defaultVmHost}
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s) > /dev/null
    trap "ssh-agent -k > /dev/null" EXIT
  fi
  for key in "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/work_ed25519 "$HOME"/.ssh/id_rsa; do
    [ -f "$key" ] && ssh-add "$key" 2>/dev/null || true
  done
''
