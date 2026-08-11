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
