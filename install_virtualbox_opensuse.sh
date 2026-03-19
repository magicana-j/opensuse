#!/usr/bin/env bash
# install_virtualbox_opensuse.sh
# openSUSE Tumbleweed / Leap 向け VirtualBox インストールスクリプト
# 使い方: sudo bash install_virtualbox_opensuse.sh

set -euo pipefail

# -------------------------------------------------------
# 色付きログ出力
# -------------------------------------------------------
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()      { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# -------------------------------------------------------
# root 権限チェック
# -------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    error "このスクリプトは sudo または root で実行してください"
    exit 1
fi

# -------------------------------------------------------
# ディストリビューション確認
# -------------------------------------------------------
if [[ ! -f /etc/os-release ]]; then
    error "/etc/os-release が見つかりません。openSUSE 以外の環境の可能性があります"
    exit 1
fi

source /etc/os-release

if [[ "$ID" != "opensuse-tumbleweed" && "$ID" != "opensuse-leap" && "$ID_LIKE" != *"suse"* ]]; then
    warn "openSUSE 以外の環境が検出されました: $PRETTY_NAME"
    warn "続行しますが、動作は保証されません"
fi

info "ディストリビューション: $PRETTY_NAME"

# -------------------------------------------------------
# パッケージリスト
# -------------------------------------------------------
PACKAGES=(
    virtualbox               # VirtualBox 本体
    virtualbox-host-source   # カーネルモジュールのソース
    kernel-devel             # カーネルヘッダ（モジュールビルドに必要）
    gcc                      # コンパイラ
    make                     # ビルドツール
    dkms                     # Dynamic Kernel Module Support
)

# -------------------------------------------------------
# zypper でインストール
# -------------------------------------------------------
info "zypper のリポジトリ情報を更新しています..."
zypper --non-interactive refresh

info "パッケージをインストールしています: ${PACKAGES[*]}"
zypper --non-interactive install --auto-agree-with-licenses "${PACKAGES[@]}"

ok "パッケージのインストールが完了しました"

# -------------------------------------------------------
# vboxdrv カーネルモジュールのビルドと読み込み
# -------------------------------------------------------
info "VirtualBox カーネルモジュールをビルドしています..."

if command -v dkms &>/dev/null; then
    # DKMS 経由でビルド（推奨）
    VB_VERSION=$(VBoxManage --version 2>/dev/null | grep -oP '^\d+\.\d+\.\d+' || true)
    if [[ -n "$VB_VERSION" ]]; then
        dkms autoinstall || warn "dkms autoinstall に失敗しました。手動で 'dkms autoinstall' を再実行してください"
    else
        warn "VirtualBox バージョンを取得できませんでした。dkms をスキップします"
    fi
else
    # フォールバック: vboxconfig スクリプト
    if [[ -x /sbin/vboxconfig ]]; then
        /sbin/vboxconfig || warn "vboxconfig の実行に失敗しました"
    fi
fi

# -------------------------------------------------------
# vboxdrv サービスの有効化と起動
# -------------------------------------------------------
info "vboxdrv サービスを有効化・起動しています..."
systemctl enable --now vboxdrv 2>/dev/null || warn "vboxdrv サービスの操作に失敗しました（リブート後に自動起動する場合があります）"

# -------------------------------------------------------
# 現在のログインユーザーを vboxusers グループに追加
# -------------------------------------------------------
# sudo 経由で実行された場合は SUDO_USER、直接 root の場合は LOGNAME を使用
TARGET_USER="${SUDO_USER:-}"

if [[ -z "$TARGET_USER" ]]; then
    warn "追加対象ユーザーを自動検出できませんでした"
    warn "手動で次のコマンドを実行してください: sudo usermod -aG vboxusers <ユーザー名>"
else
    info "ユーザー '$TARGET_USER' を vboxusers グループに追加しています..."
    usermod -aG vboxusers "$TARGET_USER"
    ok "ユーザー '$TARGET_USER' を vboxusers に追加しました"
    warn "グループ変更を反映するには、一度ログアウトして再ログインが必要です"
fi

# -------------------------------------------------------
# USB デバイスアクセス用グループ追加（任意）
# -------------------------------------------------------
if getent group disk &>/dev/null && [[ -n "${TARGET_USER:-}" ]]; then
    usermod -aG disk "$TARGET_USER" 2>/dev/null || true
fi

# -------------------------------------------------------
# VirtualBox Extension Pack（任意インストール）
# -------------------------------------------------------
echo ""
read -r -p "VirtualBox Extension Pack もインストールしますか？ (USB 2.0/3.0, RDP などが有効になります) [y/N]: " INSTALL_EXT

if [[ "$INSTALL_EXT" =~ ^[Yy]$ ]]; then
    VB_VER=$(VBoxManage --version 2>/dev/null | grep -oP '^\d+\.\d+\.\d+' || true)
    if [[ -z "$VB_VER" ]]; then
        warn "VirtualBox のバージョンを取得できませんでした。Extension Pack のインストールをスキップします"
    else
        EXT_URL="https://download.virtualbox.org/virtualbox/${VB_VER}/Oracle_VirtualBox_Extension_Pack-${VB_VER}.vbox-extpack"
        EXT_FILE="/tmp/Oracle_VirtualBox_Extension_Pack-${VB_VER}.vbox-extpack"

        info "Extension Pack をダウンロードしています: $EXT_URL"
        if curl -fL -o "$EXT_FILE" "$EXT_URL"; then
            VBoxManage extpack install --replace "$EXT_FILE" \
                && ok "Extension Pack のインストールが完了しました" \
                || warn "Extension Pack のインストールに失敗しました"
            rm -f "$EXT_FILE"
        else
            warn "Extension Pack のダウンロードに失敗しました"
        fi
    fi
fi

# -------------------------------------------------------
# 完了メッセージ
# -------------------------------------------------------
echo ""
ok "===== VirtualBox のセットアップが完了しました ====="
echo ""
echo "次のステップ:"
echo "  1. システムを再起動してカーネルモジュールを確実に読み込む"
echo "  2. 再ログインして vboxusers グループを有効にする"
echo "  3. 'VBoxManage --version' でバージョンを確認する"
echo ""
