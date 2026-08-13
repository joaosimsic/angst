{
  mkScript,
  pkgs,
}:
{
  shell,
  homeDirectory,
  username,
}:
mkScript {
  name = "angst-set-login-shell";
  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    bash
  ];
  text = ''
    if [ -e /etc/NIXOS ]; then
      $VERBOSE_ECHO "angst: NixOS detected, login shell managed by NixOS config"
      exit 0
    fi

    # Resolve the shell binary: nix profile first, then system locations.
    shell=""
    for candidate in \
      "${homeDirectory}/.nix-profile/bin/${shell}" \
      "/usr/local/bin/${shell}" \
      "/usr/bin/${shell}" \
      "/bin/${shell}"
    do
      if [ -x "$candidate" ]; then
        shell="$candidate"
        break
      fi
    done
    if [ -z "$shell" ]; then
      $VERBOSE_ECHO "angst: shell '${shell}' not found, skipping"
      exit 0
    fi

    # Run as root directly, otherwise escalate via sudo when available.
    # The home-manager activation PATH only contains nix store dirs, so fall
    # back to the well-known system locations.
    if [ "$(id -u)" -eq 0 ]; then
      priv=""
    elif command -v sudo >/dev/null 2>&1; then
      priv="sudo"
    elif [ -x /usr/bin/sudo ]; then
      priv="/usr/bin/sudo"
    elif [ -x /usr/local/bin/sudo ]; then
      priv="/usr/local/bin/sudo"
    else
      $VERBOSE_ECHO "angst: cannot set login shell: neither root nor sudo available"
      exit 0
    fi

    if command -v chsh >/dev/null 2>&1; then
      chsh_cmd="chsh"
    elif [ -x /usr/bin/chsh ]; then
      chsh_cmd="/usr/bin/chsh"
    else
      $VERBOSE_ECHO "angst: chsh not found, skipping login shell setup"
      exit 0
    fi

    escalate() {
      if [ -n "$priv" ]; then
        "$priv" "$@"
      else
        "$@"
      fi
    }

    if ! grep -qxF "$shell" /etc/shells 2>/dev/null; then
      $VERBOSE_ECHO "angst: adding $shell to /etc/shells..."
      $DRY_RUN_CMD escalate sh -c 'printf "%s\n" "$1" | tee -a /etc/shells > /dev/null' _ "$shell"
    fi

    current_shell=$(grep "^${username}:" /etc/passwd | cut -d: -f7)
    if [ "$current_shell" != "$shell" ]; then
      $VERBOSE_ECHO "angst: setting login shell to $shell..."
      $DRY_RUN_CMD escalate "$chsh_cmd" -s "$shell" "${username}"
    fi
  '';
}
