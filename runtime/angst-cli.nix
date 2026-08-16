# The `angst` CLI — single assembly of every runtime command.
#
# Small parts (lib, bootstrap-secrets, render, watch, main dispatcher) fold
# inline below; the ~16 KB `angst-projects.sh` stays a readFile'd sibling to
# avoid re-indenting churn (shared with `projects-sync.nix`).
{
  mkScript,
  pkgs,
}:

mkScript {
  name = "angst";
  runtimeInputs = with pkgs; [
    coreutils
    findutils
    git
    nix
    watchexec
    jq
    sops
    age
    openssl
    openssh
    diffutils
  ];
  text = builtins.concatStringsSep "\n" [
    (builtins.readFile ./angst-lib.sh)
    ''
      usage() {
          cat <<'EOF'
      Usage:
        angst bootstrap-secrets [--host HOST]
        angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
        angst watch  [--repo PATH] [--host HOST] [--theme THEME]
        angst projects <add|sync|status|capture|edit-env|rm> ...
        angst ssh-key <generate|verify> --scope personal|work
      EOF
      }

      find_host_config_dir() {
          local repo="$1" host="$2"
          for d in "$repo/hosts/"*/; do
              [ -d "$d" ] || continue
              local dn
              dn="$(basename "$d")"
              if [ -f "$repo/hosts/$dn/$host/default.nix" ]; then
                  echo "$repo/hosts/$dn/$host"
                  return 0
              fi
          done
          if [ -f "$repo/hosts/$host/default.nix" ]; then
              echo "$repo/hosts/$host"
              return 0
          fi
          return 1
      }

      config_val() {
          local repo="$1" host="$2" key="$3"
          local dir
          dir="$(find_host_config_dir "$repo" "$host")" || return 1
          nix eval --file "$dir/default.nix" --raw --apply "x: x.$key or null" 2>/dev/null || true
      }

      reload_hooks() {
          if command -v i3-msg >/dev/null 2>&1 && [ -n "''${I3SOCK:-}" ]; then
              i3-msg reload >/dev/null || true
          fi
      }
    ''
    ''
      bootstrap_secrets_cmd() {
          local repo_root host_name="nixos"
          repo_root="$(repo_root_default)"

          while [ "$#" -gt 0 ]; do
              case "$1" in
              --host)
                  host_name="$2"
                  shift 2
                  ;;
              -h | --help)
                  usage
                  return 0
                  ;;
              *)
                  echo "unknown bootstrap-secrets option: $1" >&2
                  usage >&2
                  return 2
                  ;;
              esac
          done

          if ! command -v sops >/dev/null 2>&1; then
              echo "Error: sops is not available. Install it first (e.g., nix shell nixpkgs#sops)" >&2
              return 1
          fi

          if ! command -v mkpasswd >/dev/null 2>&1; then
              echo "Error: mkpasswd is not available. Install whois or use nix environment." >&2
              return 1
          fi

          local config_dir secrets_file config_file
          config_dir="$(find_host_config_dir "$repo_root" "$host_name")" || {
              echo "Error: host config not found for '$host_name'" >&2
              return 1
          }
          secrets_file="$config_dir/secrets.yaml"
          config_file="$config_dir/default.nix"

          if [ ! -f "$config_file" ]; then
              echo "Error: host config not found for '$host_name'" >&2
              return 1
          fi

          printf "Master password: "
          read -rs master_password
          printf "\n"

          if [ -z "$master_password" ]; then
              echo "Error: password cannot be empty" >&2
              return 1
          fi

          printf "Confirm master password: "
          read -rs confirm
          printf "\n"

          if [ "$master_password" != "$confirm" ]; then
              echo "Error: passwords do not match" >&2
              return 1
          fi
          unset confirm

          local hash
          hash="$(mkpasswd -m sha-512 "$master_password")" || {
              echo "Error: failed to hash password" >&2
              return 1
          }

          if [ -f "$secrets_file" ]; then
              echo "masterPassword: \"$master_password\"" | sops --input-type yaml --output-type yaml "$secrets_file" 2>/dev/null || {
                  echo "Error: failed to update $secrets_file" >&2
                  return 1
              }
          else
              echo "masterPassword: \"$master_password\"" | sops --input-type yaml --output-type yaml "$secrets_file" 2>/dev/null || {
                  echo "Error: failed to create $secrets_file" >&2
                  return 1
              }
          fi

          if grep -q '^\s*password\s*=' "$config_file"; then
              sed -i "s|^\s*password\s*=.*|  password = \"$hash\";|" "$config_file"
          else
              sed -i "/^\s*};/i\  password = \"$hash\";" "$config_file"
          fi

          unset master_password hash

          echo "Secrets bootstrapped for $host_name:"
          echo "  secrets: $secrets_file"
          echo "  hash:    $config_file"
          echo ""
          echo "Run 'sudo nixos-rebuild switch --flake .#$host_name' to apply."
      }
    ''
    ''
      ssh_key_usage() {
          cat <<'EOF'
      Usage:
        angst ssh-key generate --scope personal|work
        angst ssh-key verify   --scope personal|work
      EOF
      }

      ssh_key_scope_keyfile() {
          case "$1" in
          personal) printf '%s\n' "$HOME/.config/sops/age/keys.txt" ;;
          work) printf '%s\n' "$HOME/.config/sops/age/work-keys.txt" ;;
          esac
      }

      ssh_key_dest() {
          case "$1" in
          personal) printf '%s\n' "id_ed25519" ;;
          work) printf '%s\n' "work_ed25519" ;;
          esac
      }

      ssh_key_generate_cmd() {
          local scope=""
          while [ "$#" -gt 0 ]; do
              case "$1" in
              --scope)
                  scope="''${2:-}"
                  if [ -z "$scope" ]; then
                      echo "error: --scope requires a value (personal|work)" >&2
                      return 2
                  fi
                  shift 2
                  ;;
              -h | --help)
                  ssh_key_usage
                  return 0
                  ;;
              *)
                  echo "unknown ssh-key generate option: $1" >&2
                  ssh_key_usage >&2
                  return 2
                  ;;
              esac
          done
          case "$scope" in
          personal | work) ;;
          *)
              echo "error: invalid scope '$scope' (personal|work)" >&2
              ssh_key_usage >&2
              return 2
              ;;
          esac

          local repo keyfile recipient dir
          repo="$(repo_root_default)"
          keyfile="$(ssh_key_scope_keyfile "$scope")"
          if [ ! -f "$keyfile" ]; then
              echo "error: no $scope age key at $keyfile" >&2
              return 1
          fi
          recipient="$(age-keygen -y "$keyfile" 2>/dev/null)" || {
              echo "error: could not derive the $scope age recipient from $keyfile" >&2
              return 1
          }

          dir="$repo/secrets/ssh"
          mkdir -p "$dir" || return 1
          tmp="$(mktemp -d)" || return 1
          trap 'rm -rf "$tmp"' EXIT

          ssh-keygen -q -t ed25519 -N "" -f "$tmp/sshkey" -C "angst-$scope" || return 1
          age -r "$recipient" -o "$dir/$scope.ed25519.age" "$tmp/sshkey" || {
              echo "error: age encryption failed (recipient $recipient)" >&2
              return 1
          }
          cp "$tmp/sshkey.pub" "$dir/$scope.ed25519.pub" || return 1
          chmod 644 "$dir/$scope.ed25519.pub" 2>/dev/null || true

          echo "generated $scope SSH key:"
          echo "  private (age-encrypted): $dir/$scope.ed25519.age"
          echo "  public (committed):      $dir/$scope.ed25519.pub"
          echo ""
          echo "public key: $(cat "$dir/$scope.ed25519.pub")"
          echo ""
          echo "authorize it at the $scope provider, then run:"
          echo "  angst ssh-key verify --scope $scope"
      }

      ssh_key_verify_cmd() {
          local scope=""
          while [ "$#" -gt 0 ]; do
              case "$1" in
              --scope)
                  scope="''${2:-}"
                  if [ -z "$scope" ]; then
                      echo "error: --scope requires a value (personal|work)" >&2
                      return 2
                  fi
                  shift 2
                  ;;
              -h | --help)
                  ssh_key_usage
                  return 0
                  ;;
              *)
                  echo "unknown ssh-key verify option: $1" >&2
                  ssh_key_usage >&2
                  return 2
                  ;;
              esac
          done
          case "$scope" in
          personal | work) ;;
          *)
              echo "error: invalid scope '$scope' (personal|work)" >&2
              ssh_key_usage >&2
              return 2
              ;;
          esac

          local repo keyfile dir age_file pub_file pub derived
          repo="$(repo_root_default)"
          keyfile="$(ssh_key_scope_keyfile "$scope")"
          dir="$repo/secrets/ssh"
          age_file="$dir/$scope.ed25519.age"
          pub_file="$dir/$scope.ed25519.pub"
          if [ ! -f "$keyfile" ]; then
              echo "error: no $scope age key at $keyfile" >&2
              return 1
          fi
          if [ ! -f "$age_file" ] || [ ! -f "$pub_file" ]; then
              echo "error: missing $dir/$scope.ed25519.{age,pub}; run 'angst ssh-key generate --scope $scope' first" >&2
              return 1
          fi

          tmp="$(mktemp -d)" || return 1
          trap 'rm -rf "$tmp"' EXIT
          age -d -i "$keyfile" -o "$tmp/sshkey" "$age_file" 2>/dev/null || {
              echo "FAIL: could not decrypt $age_file with the $scope age key" >&2
              return 1
          }
          chmod 600 "$tmp/sshkey"
          pub="$(cat "$pub_file")"
          derived="$(ssh-keygen -y -f "$tmp/sshkey" 2>/dev/null)" || {
              echo "FAIL: decrypted $age_file is not a valid OpenSSH private key" >&2
              return 1
          }
          if [ "$pub" = "$derived" ]; then
              echo "PASS: $scope.ed25519.pub matches the key inside $scope.ed25519.age"
              return 0
          fi
          echo "FAIL: $scope.ed25519.pub does not match the key inside $scope.ed25519.age" >&2
          echo "  committed: $pub" >&2
          echo "  derived:   $derived" >&2
          return 1
      }

      ssh_key_cmd() {
          local cmd="''${1:-}"
          if [ "$#" -gt 0 ]; then shift; fi
          case "$cmd" in
          generate) ssh_key_generate_cmd "$@" ;;
          verify) ssh_key_verify_cmd "$@" ;;
          -h | --help | "") ssh_key_usage ;;
          *)
              echo "unknown ssh-key command: $cmd" >&2
              ssh_key_usage >&2
              return 2
              ;;
          esac
      }
    ''
    ''
      render_cmd() {
          local repo_root host_name theme_name=""
          repo_root="$(repo_root_default)"
          host_name="''${NIX_DEFAULT_TARGET_HOST:-''${ANGST_HOST:-nixos}}"
          local should_reload=1

          while [ "$#" -gt 0 ]; do
              case "$1" in
              --repo)
                  repo_root="$2"
                  shift 2
                  ;;
              --host)
                  host_name="$2"
                  shift 2
                  ;;
              --theme)
                  theme_name="$2"
                  shift 2
                  ;;
              --reload)
                  should_reload=1
                  shift
                  ;;
              --no-reload)
                  should_reload=0
                  shift
                  ;;
              -h | --help)
                  usage
                  return 0
                  ;;
              *)
                  echo "unknown render option: $1" >&2
                  usage >&2
                  return 2
                  ;;
              esac
          done

          if [ -z "$theme_name" ]; then
              theme_name="$(config_val "$repo_root" "$host_name" "theme")"
              theme_name="''${theme_name:-monochrome}"
          fi

          if [ ! -d "$repo_root/domains" ]; then
              echo "domains directory not found under $repo_root" >&2
              return 1
          fi

          local theme_found=
          for f in "$repo_root/themes/"*.nix; do
              [ -f "$f" ] || continue
              local base
              base="$(basename "$f" .nix)"
              [ "$base" = "default" ] || [ "$base" = "schema" ] && continue
              if [ "$base" = "$theme_name" ]; then
                  theme_found=1
                  break
              fi
          done

          if [ -z "$theme_found" ]; then
              echo "Unknown theme '$theme_name'. Available themes:" >&2
              for f in "$repo_root/themes/"*.nix; do
                  [ -f "$f" ] || continue
                  local base
                  base="$(basename "$f" .nix)"
                  [ "$base" = "default" ] || [ "$base" = "schema" ] && continue
                  echo "  $base" >&2
              done
              return 1
          fi

          echo "Evaluating templates in a single optimized batch..."
          local json_data
          json_data=$(nix eval "$repo_root#lib.renderDomainOutputsFor" \
              --apply "f: builtins.toJSON (map (o: { path = o.path; text = o.text; }) (f \"$theme_name\"))" --raw)

          while IFS= read -r path; do
              [ -n "$path" ] || continue
              local output="$repo_root/$path"
              mkdir -p "$(dirname "$output")"
              echo "$json_data" | jq -r ".[] | select(.path == \"$path\") | .text" >"$output"
              chmod u+w "$output"
              echo "rendered $path"
          done < <(echo "$json_data" | jq -r '.[] | .path')

          local unique_dirs
          unique_dirs=$(echo "$json_data" | jq -r '.[] | .path' | while IFS= read -r p; do
              echo "$p" | cut -d/ -f1-4
          done | sort -u)

          if [ -n "$unique_dirs" ]; then
              for config_dir in $unique_dirs; do
                  local rel_paths
                  rel_paths=$(echo "$json_data" | jq -r '.[] | .path' | while IFS= read -r p; do
                      case "$p" in
                      "$config_dir/"*) echo "''${p#"$config_dir"/}" ;;
                      esac
                  done | sort -u)

                  local gitignore_path="$repo_root/$config_dir/.gitignore"
                  if [ -f "$gitignore_path" ]; then
                      local combined
                      combined=$(printf '%s\n%s' "$rel_paths" "$(cat "$gitignore_path")" | sort -u)
                      printf '%s\n' "$combined" >"$gitignore_path"
                  else
                      printf '%s\n' "$rel_paths" >"$gitignore_path"
                  fi
                  echo "synced $config_dir/.gitignore"
              done
          fi

          if [ "$should_reload" -eq 1 ]; then
              reload_hooks
          fi
      }
    ''
    ''
      watch_cmd() {
          local repo_root host_name theme_name="''${ANGST_THEME:-}"
          repo_root="$(repo_root_default)"
          host_name="''${NIX_DEFAULT_TARGET_HOST:-''${ANGST_HOST:-nixos}}"

          while [ "$#" -gt 0 ]; do
              case "$1" in
              --repo)
                  repo_root="$2"
                  shift 2
                  ;;
              --host)
                  host_name="$2"
                  shift 2
                  ;;
              --theme)
                  theme_name="$2"
                  shift 2
                  ;;
              -h | --help)
                  usage
                  return 0
                  ;;
              *)
                  echo "unknown watch option: $1" >&2
                  usage >&2
                  return 2
                  ;;
              esac
          done

          local args=(render --repo "$repo_root" --host "$host_name" --reload)
          if [ -n "$theme_name" ]; then args+=(--theme "$theme_name"); fi

          local watch_path="$repo_root/hosts/$host_name"
          local resolved
          resolved="$(find_host_config_dir "$repo_root" "$host_name")" && watch_path="$resolved"

          watchexec \
              --watch "$repo_root/themes" \
              --watch "$repo_root/domains" \
              --watch "$watch_path" \
              -- "$0" "''${args[@]}"
      }
    ''
    (builtins.readFile ./angst-projects.sh)
    ''
      command="''${1:-}"
      if [ "$#" -gt 0 ]; then shift; fi

      case "$command" in
      bootstrap-secrets) bootstrap_secrets_cmd "$@" ;;
      render) render_cmd "$@" ;;
      watch) watch_cmd "$@" ;;
      projects) angst_projects_cmd "$@" ;;
      ssh-key) ssh_key_cmd "$@" ;;
      -h | --help | "") usage ;;
      *)
          echo "unknown command: $command" >&2
          usage >&2
          exit 2
          ;;
      esac
    ''
  ];
}
