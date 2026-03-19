#!/bin/sh
# (header reserved for user)

set -e

# --- Configuration ---
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
IDENTITY_FILE="$SSH_DIR/id_ed25519"
GH_HOST="github.com"
GH_USER="git"

# --- Functions ---
print_info()    { echo "[INFO] $1"; }
print_success() { echo "[OK]   $1"; }
print_error()   { echo "[ERR]  $1" >&2; }

# --- Preflight checks ---
if [ ! -f "$IDENTITY_FILE" ]; then
    print_error "SSH key not found: $IDENTITY_FILE"
    print_error "Run 'generate_ssh_key.sh' first."
    exit 1
fi

# --- Write ~/.ssh/config ---
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Check if a Host github.com block already exists
if grep -qF "Host $GH_HOST" "$SSH_CONFIG" 2>/dev/null; then
    print_info "Host $GH_HOST entry already exists in $SSH_CONFIG — skipping."
else
    # Append block (add blank line separator if file is non-empty)
    if [ -s "$SSH_CONFIG" ]; then
        printf '\n' >> "$SSH_CONFIG"
    fi
    cat >> "$SSH_CONFIG" << EOF
Host $GH_HOST
    HostName $GH_HOST
    User $GH_USER
    IdentityFile $IDENTITY_FILE
    IdentitiesOnly yes
EOF
    chmod 600 "$SSH_CONFIG"
    print_success "Added Host $GH_HOST block to $SSH_CONFIG"
fi

# --- git config: use SSH URL format for github.com ---
git config --global "url.git@${GH_HOST}:.insteadOf" "https://${GH_HOST}/"
print_success "git config: url.git@${GH_HOST}:.insteadOf = https://${GH_HOST}/"

# --- Connection test ---
echo
print_info "Testing SSH connection to $GH_HOST ..."
# ssh exits with code 1 on success (authenticated but no shell), so suppress set -e
ssh_output="$(ssh -T -o StrictHostKeyChecking=accept-new "git@$GH_HOST" 2>&1)" || true
echo "$ssh_output"
case "$ssh_output" in
    *"successfully authenticated"*)
        print_success "SSH authentication to $GH_HOST succeeded."
        ;;
    *"Permission denied"*)
        print_error "Permission denied. Is the public key registered on GitHub?"
        echo
        print_info "Public key to register:"
        cat "${IDENTITY_FILE}.pub"
        exit 1
        ;;
    *)
        print_info "Could not confirm authentication. Check the output above."
        ;;
esac

echo
print_success "GitHub SSH setup complete."
