{ config, lib, pkgs, ... }:
{
  home.activation.cleanStaleDesktopShadows = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    verboseEcho "Cleaning stale desktop shadows in ~/.local/share/applications"
    shopt -s nullglob
    for stale in "$HOME/.local/share/applications/"*.desktop; do
      [ -e "$stale" ] || continue
      # Keep HM-managed symlinks (e.g. mimeapps.list -> *-home-manager-files*)
      # and our own Mint visibility symlinks -> ~/.nix-profile/share/...
      if [ -L "$stale" ]; then
        link_target="$(readlink "$stale")"
        case "$link_target" in
          ${lib.escapeShellArg builtins.storeDir}/*"-home-manager-files"*) continue ;;
          ${lib.escapeShellArg builtins.storeDir}/*"-home-manager-path"*) continue ;;
          "$HOME/.nix-profile/share/applications/"*) 
            # already correctly linked for Mint menu (our bottom loop)
            # verify it still points to valid file and has same content
            if [ -e "$stale" ] && cmp -s "$stale" "$link_target" 2>/dev/null; then
              continue
            fi
            ;;
        esac
      fi
      bn="$(basename "$stale")"
      profile_target="$HOME/.nix-profile/share/applications/$bn"
      system_target="/run/current-system/sw/share/applications/$bn"
      target=""
      if [ -f "$profile_target" ]; then
        target="$profile_target"
      elif [ -f "$system_target" ]; then
        target="$system_target"
      else
        # No counterpart in profile/system -> legitimate user file (linphone, burp, webapp, claude) -> keep
        continue
      fi
      # Safe: only shadows with profile counterpart are considered.
      # Preserves intentional custom overrides without store path (different Exec/Icon).
      # Replaces stale with symlink to profile so Mint Cinnamon menu sees it.
      needs_replace=false
      if cmp -s "$stale" "$target" 2>/dev/null; then
        verboseEcho "Replacing stale shadow $stale (identical to $target) with symlink"
        needs_replace=true
      elif grep -q "^MimeType=" "$target" 2>/dev/null && ! grep -q "^MimeType=" "$stale" 2>/dev/null; then
        verboseEcho "Replacing stale shadow $stale (missing MimeType, profile has $target) with symlink"
        needs_replace=true
      elif grep -q "/nix/store" "$stale" 2>/dev/null && grep -q "/nix/store" "$target" 2>/dev/null; then
        verboseEcho "Replacing stale shadow $stale (outdated store path, profile has $target) with symlink"
        needs_replace=true
      fi
      if [ "$needs_replace" = true ]; then
        ln -sf "$target" "$stale"
      fi
    done
    # Ensure paper and any other profile desktop files are visible in ~/.local/share for Mint Cinnamon
    # (profile ~/.nix-profile/share may not be in XDG_DATA_DIRS for Cinnamon session)
    for src in "$HOME/.nix-profile/share/applications/"*.desktop; do
      [ -e "$src" ] || continue
      bn="$(basename "$src")"
      dest="$HOME/.local/share/applications/$bn"
      if [ ! -e "$dest" ]; then
        verboseEcho "Linking $bn for Mint menu ($src -> $dest)"
        ln -sf "$src" "$dest"
      fi
    done
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
  '';
}
