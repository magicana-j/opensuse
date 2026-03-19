#!/bin/sh
# (header reserved for user)

set -e

# --- Functions ---
print_info()    { echo "[INFO] $1"; }
print_success() { echo "[OK]   $1"; }
print_error()   { echo "[ERR]  $1" >&2; }

# --- Install git if missing ---
if ! command -v git > /dev/null 2>&1; then
    print_info "git not found. Installing via zypper..."
    if ! command -v zypper > /dev/null 2>&1; then
        print_error "zypper not found. Is this an openSUSE/SLES system?"
        exit 1
    fi
    zypper install --non-interactive git
    print_success "git installed."
else
    print_info "git is already installed: $(git --version)"
fi

# --- Main ---
echo
echo "=== Git Default Configuration ==="
echo

# User info
read -rp "Username: " git_user
if [ -z "$git_user" ]; then
    print_error "Username is required."
    exit 1
fi

read -rp "Email address: " git_email
if [ -z "$git_email" ]; then
    print_error "Email address is required."
    exit 1
fi

# Remote connection method
echo
echo "Remote connection method:"
echo "  1) SSH"
echo "  2) Token (HTTPS)"
read -rp "Select [1/2]: " conn_choice

case "$conn_choice" in
    1)
        CONN_METHOD="ssh"
        git config --global --unset credential.helper 2>/dev/null || true
        ;;
    2)
        CONN_METHOD="token"
        if command -v git-credential-manager > /dev/null 2>&1; then
            git config --global credential.helper manager
        else
            git config --global credential.helper "cache --timeout=28800"
        fi
        ;;
    *)
        print_error "Invalid selection."
        exit 1
        ;;
esac

# --- Apply settings ---
git config --global user.name  "$git_user"
git config --global user.email "$git_email"
git config --global init.defaultBranch main

git config --global core.autocrlf input
git config --global pull.rebase false
git config --global push.autoSetupRemote true
git config --global core.editor "${EDITOR:-vi}"

# --- Summary ---
echo
echo "=== Applied Configuration ==="
echo "  user.name            : $git_user"
echo "  user.email           : $git_email"
echo "  init.defaultBranch   : main"
echo "  connection method    : $CONN_METHOD"
echo "  core.autocrlf        : input"
echo "  pull.rebase          : false"
echo "  push.autoSetupRemote : true"
echo "  core.editor          : ${EDITOR:-vi}"
echo
git config --global --list | grep -E "^(user|init|credential|core|pull|push)" || true
echo
print_success "Git configuration complete."

if [ "$CONN_METHOD" = "ssh" ]; then
    echo
    print_info "Make sure your SSH public key is registered with your Git host (GitHub/GitLab/etc.)."
    print_info "Run 'generate_ssh_key.sh' if you haven't generated a key yet."
fi
