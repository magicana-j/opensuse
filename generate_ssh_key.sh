#!/bin/bash
# SSH Key Generation Script

set -e

# --- Configuration ---
KEY_DIR="$HOME/.ssh"
DEFAULT_KEY_NAME="id_ed25519"

# --- Functions ---
print_info()    { echo "[INFO] $1"; }
print_success() { echo "[OK]   $1"; }
print_error()   { echo "[ERR]  $1" >&2; }

# --- Main ---
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

echo "=== SSH Key Generation ==="
echo

# Key type selection
echo "Key type:"
echo "  1) ed25519 (recommended)"
echo "  2) rsa (4096-bit)"
read -rp "Select [1/2] (default: 1): " key_type_choice
key_type_choice="${key_type_choice:-1}"

case "$key_type_choice" in
    1) KEY_TYPE="ed25519"; KEY_BITS="" ;;
    2) KEY_TYPE="rsa";     KEY_BITS="-b 4096" ;;
    *) print_error "Invalid selection."; exit 1 ;;
esac

# Key filename
read -rp "Key filename (default: $DEFAULT_KEY_NAME): " key_name
key_name="${key_name:-$DEFAULT_KEY_NAME}"
KEY_PATH="$KEY_DIR/$key_name"

if [ -f "$KEY_PATH" ]; then
    read -rp "Key '$KEY_PATH' already exists. Overwrite? [y/N]: " overwrite
    case "$overwrite" in
        [Yy]) : ;;
        *)

            print_info "Aborted."
            exit 0
            ;;
    esac
fi

# Comment (usually email)
read -rp "Comment (e.g. your email): " comment

# Passphrase prompt is handled by ssh-keygen itself
echo
print_info "Generating $KEY_TYPE key..."
# shellcheck disable=SC2086
ssh-keygen -t "$KEY_TYPE" $KEY_BITS -C "$comment" -f "$KEY_PATH"

chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"

print_success "Private key: $KEY_PATH"
print_success "Public key:  ${KEY_PATH}.pub"
echo
echo "--- Public key (copy this to your service) ---"
cat "${KEY_PATH}.pub"
echo "----------------------------------------------"

# Optionally add to ssh-agent
if command -v ssh-agent &>/dev/null; then
    read -rp "Add key to ssh-agent? [Y/n]: " add_agent
    add_agent="${add_agent:-Y}"
    case "$add_agent" in
        [Yy])
        eval "$(ssh-agent -s)" &>/dev/null || true
            ssh-add "$KEY_PATH"
            print_success "Key added to ssh-agent."
            ;;
    esac
fi

echo
print_success "Done."
