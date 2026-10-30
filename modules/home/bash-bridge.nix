{ lib, ... }:

{
  # Bash (and tools launched from bash, e.g. opencode) never sourced
  # hm-session-vars.sh: only nushell did (via env.nu). Without this,
  # CARGO_BUILD_RUSTFLAGS / NIX_LD_* silently miss the build shell and
  # cargo links nix glibc without the bevy RPATH. Idempotently append a
  # source line to ~/.profile (login shells) and ~/.bashrc (interactive
  # non-login shells).
  home.activation.hmSessionVarsForBash = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SRC_LINE='[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"'
    for target in "$HOME/.profile" "$HOME/.bashrc"; do
      if [ -f "$target" ]; then
        if ! grep -q 'hm-session-vars\.sh' "$target" 2>/dev/null; then
          $DRY_RUN_CMD echo "" >> "$target"
          $DRY_RUN_CMD echo '# Managed by angst (bash-bridge): load home-manager session vars.' >> "$target"
          $DRY_RUN_CMD echo "$SRC_LINE" >> "$target"
          $VERBOSE_ECHO "angst bash-bridge: sourced hm-session-vars in $target"
        fi
      elif [ "$target" = "$HOME/.profile" ]; then
        $DRY_RUN_CMD echo '# Managed by angst (bash-bridge): load home-manager session vars.' > "$target"
        $DRY_RUN_CMD echo "$SRC_LINE" >> "$target"
        $VERBOSE_ECHO "angst bash-bridge: created $target"
      fi
    done
  '';
}
