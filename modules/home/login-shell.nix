{
  config,
  lib,
  pkgs,
  shell,
  ...
}:

let
  cfg = config.angst.loginShell;

  candidates = [
    "${config.home.homeDirectory}/.nix-profile/bin/${cfg.shell}"
    "/usr/local/bin/${cfg.shell}"
    "/usr/bin/${cfg.shell}"
    "/bin/${cfg.shell}"
  ];

  shellFound = lib.any (c: builtins.pathExists c) candidates;

  loginShellScript = pkgs.writeShellApplication {
    name = "angst-set-login-shell";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      bash
    ];
    text = ''
      shell_name="$1"
      home_dir="$2"
      username="$3"

      if [ -e /etc/NIXOS ]; then
        $VERBOSE_ECHO "angst: NixOS detected, login shell managed by NixOS config"
        exit 0
      fi

      # Resolve the shell binary: nix profile first, then system locations.
      shell=""
      for candidate in \
        "$home_dir/.nix-profile/bin/$shell_name" \
        "/usr/local/bin/$shell_name" \
        "/usr/bin/$shell_name" \
        "/bin/$shell_name"
      do
        if [ -x "$candidate" ]; then
          shell="$candidate"
          break
        fi
      done
      if [ -z "$shell" ]; then
        $VERBOSE_ECHO "angst: shell '$shell_name' not found, skipping"
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

      current_shell=$(grep "^$username:" /etc/passwd | cut -d: -f7)
      if [ "$current_shell" != "$shell" ]; then
        $VERBOSE_ECHO "angst: setting login shell to $shell..."
        $DRY_RUN_CMD escalate "$chsh_cmd" -s "$shell" "$username"
      fi
    '';
  };
in
{
  options.angst.loginShell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Sync the login shell on non-NixOS systems (adds to /etc/shells and chsh)";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = shell;
      description = "Name of the shell to set as the login shell";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.shell != "") {
    assertions = [
      {
        assertion = shellFound;
        message = "angst: login shell '${cfg.shell}' not found (checked ${lib.concatStringsSep ", " candidates}). Install it via home packages or a system package.";
      }
    ];

    home.activation.setLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      VERBOSE_ECHO="$VERBOSE_ECHO" DRY_RUN_CMD="$DRY_RUN_CMD" \
        ${loginShellScript}/bin/angst-set-login-shell "${cfg.shell}" "${config.home.homeDirectory}" "${config.home.username}"
    '';
  };
}
