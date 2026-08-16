{
  mkScript,
  pkgs,
}:
{
  homeDirectory,
  configs,
}:
mkScript {
  name = "angst-ftp-secrets-home";
  runtimeInputs = with pkgs; [
    sops
    age
    coreutils
  ];
  text = builtins.concatStringsSep "\n" (
    [
      ''
        set -uo pipefail

        work_key="''${SOPS_WORK_AGE_KEY_FILE:-$HOME/.config/sops/age/work-keys.txt}"

        if [ ! -f "$work_key" ]; then
          echo "warn: work age key not found at $work_key; cannot decrypt ftp configs" >&2
          exit 0
        fi

        mkdir -p "${homeDirectory}/.secrets/ftp"
        chmod 700 "${homeDirectory}/.secrets" 2>/dev/null || true
        chmod 700 "${homeDirectory}/.secrets/ftp"

        decrypt() {
          local src="$1" dest="$2"
          if [ ! -f "$src" ]; then
            echo "warn: ftp config not found at $src" >&2
            return 0
          fi
          if ! SOPS_AGE_KEY_FILE="$work_key" sops -d --input-type binary --output-type binary "$src" > "${homeDirectory}/$dest.tmp" 2>/dev/null; then
            echo "warn: could not decrypt $src" >&2
            rm -f "${homeDirectory}/$dest.tmp"
            return 0
          fi
          chmod 600 "${homeDirectory}/$dest.tmp"
          mv -f "${homeDirectory}/$dest.tmp" "${homeDirectory}/$dest"
          echo "decrypted ftp config -> ${homeDirectory}/$dest"
        }
      ''
    ]
    ++ map (c: "decrypt \"${c.source}\" \"${c.dest}\"") configs
    ++ [ "" ]
  );
}
