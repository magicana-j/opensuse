#!/bin/bash

# 0. root権限（sudo）のチェック
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo."
  echo "Usage: sudo ./setup_haskell.sh"
  exit 1
fi

# 実行ユーザーの特定（GHCupをrootではなく一般ユーザーのホームに送るため）
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "Starting setup for user: $REAL_USER"

# zlib系のどちらかが入っていればスキップし、なければ互換版を入れる
if rpm -q zlib-ng-compat-devel &>/dev/null || rpm -q zlib-devel &>/dev/null; then
    echo "zlib development package is already installed."
    ZLIB_PKG=""
else
    ZLIB_PKG="zlib-ng-compat-devel"
fi

# 1. 必要なシステム依存パッケージのインストール
echo "Installing system dependencies via zypper..."
zypper install -y curl gcc make libffi-devel gmp-devel $ZLIB_PKG zlib-devel-static ncurses-devel

# 2. GHCupの非対話インストール
# 一般ユーザーの権限で実行するように sudo -u を使用
echo "Installing GHCup and Haskell toolchain for $REAL_USER..."
export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
export BOOTSTRAP_HASKELL_GHC_VERSION=latest
export BOOTSTRAP_HASKELL_CABAL_VERSION=latest
export BOOTSTRAP_HASKELL_STACK_VERSION=latest
export BOOTSTRAP_HASKELL_INSTALL_HLS=1
export BOOTSTRAP_HASKELL_ADJUST_BASHRC=1

sudo -u "$REAL_USER" -i bash <<EOF
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
EOF

echo "--------------------------------------------------"
echo "Setup complete!"
echo "Please restart your terminal or run: source ~/.bashrc"
echo "Then, verify with: ghc --version"
