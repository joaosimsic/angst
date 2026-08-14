# Shared SSH key collection for VM runner scripts.
# Requires KEY_DIR and KEY_FILE to be set by the caller.
collect_ssh_keys() {
    mkdir -p "$KEY_DIR"

    local tmp_keys
    tmp_keys="$(mktemp)"
    trap "rm -f '$tmp_keys'" EXIT

    if ssh-add -L >/dev/null 2>&1; then
        ssh-add -L >>"$tmp_keys"
    fi

    for pubkey in "$HOME"/.ssh/*.pub; do
        if [ -r "$pubkey" ]; then
            cat "$pubkey" >>"$tmp_keys"
        fi
    done

    awk '/^(ssh-rsa|ssh-ed25519|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)/ { print }' "$tmp_keys" | sort -u >"$KEY_FILE"
    chmod 600 "$KEY_FILE"

    if [ ! -s "$KEY_FILE" ]; then
        echo "Error: no SSH public keys found in ssh-agent or ~/.ssh/*.pub for VM access."
        echo "Run ssh-add ~/.ssh/id_ed25519 or create a public key file before starting the VM."
        exit 1
    fi

    if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
        cp "$HOME/.config/sops/age/keys.txt" "$KEY_DIR/age-keys.txt"
        chmod 600 "$KEY_DIR/age-keys.txt"
    fi

    if [ -f "$HOME/.config/sops/age/work-keys.txt" ]; then
        cp "$HOME/.config/sops/age/work-keys.txt" "$KEY_DIR/work-keys.txt"
        chmod 600 "$KEY_DIR/work-keys.txt"
    fi
}
