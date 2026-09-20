#!/usr/bin/env bash
#
# makuai-slide-scheduler をサイネージモードで起動する。
#
#   ./signage.sh             キオスク表示で起動する（本番）
#   ./signage.sh --windowed  ウィンドウで起動する（本番前の確認用）
#   ./signage.sh --help
#
# Raspberry Pi OS を想定しているが、Chromium がある Linux なら動く。
# `--` 以降の引数は Chromium にそのまま渡す。
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
page="$here/index.html"
# 既定ではブラウザ本来のプロファイルを使う。index.html をダブルクリックして
# 登録した内容を、そのままサイネージ表示に出すため。MAKUAI_PROFILE を指定した
# ときだけ専用のプロファイルに切り替える。
profile="${MAKUAI_PROFILE:-}"
kiosk=1

usage() {
  cat <<'USAGE'
makuai-slide-scheduler をサイネージモードで起動します。

  ./signage.sh              キオスク表示で起動する（本番）
  ./signage.sh --windowed   ウィンドウで起動する（本番前の確認用）
  ./signage.sh -- <引数...>  以降を Chromium にそのまま渡す

環境変数:
  MAKUAI_PROFILE   Chromium のプロファイルを専用のものに分けたいときに指定。
                   既定ではブラウザ本来のプロファイルを使うので、
                   index.html をダブルクリックして登録した内容がそのまま出ます。

登壇スケジュールの登録は index.html を開いて行ってください。
このスクリプトは、登録済みの内容をキオスク表示するためのものです。
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --windowed) kiosk=0; shift ;;
    --)         shift; break ;;
    -*)         echo "signage.sh: 不明な引数: $1" >&2; echo >&2; usage >&2; exit 2 ;;
    *)          echo "signage.sh: 不明な引数: $1" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -f "$page" ]; then
  echo "signage.sh: index.html が見つかりません: $page" >&2
  echo "  このスクリプトは index.html と同じ場所に置いてください。" >&2
  exit 1
fi

# ---------- Chromium を探す ----------
browser=""
for candidate in chromium chromium-browser chromium-bin google-chrome-stable google-chrome; do
  if command -v "$candidate" >/dev/null 2>&1; then browser="$candidate"; break; fi
done
if [ -z "$browser" ]; then
  echo "signage.sh: Chromium が見つかりません。" >&2
  echo "  Raspberry Pi OS なら: sudo apt install -y chromium-browser" >&2
  exit 1
fi

# 設定の置き場所。exit_type の書き換えに使う。
if [ -n "$profile" ]; then
  config_dir="$profile"
else
  case "$browser" in
    google-chrome*) config_dir="$HOME/.config/google-chrome" ;;
    *)              config_dir="$HOME/.config/chromium" ;;
  esac
fi

# ---------- すでに開いているブラウザがあると、キオスクにならない ----------
# 同じプロファイルで起動中だと、Chromium は新しいウィンドウを既存のプロセスに
# 任せてしまい、--kiosk が効かずに普通のタブが開くだけになる。
lock="$config_dir/SingletonLock"
if [ -L "$lock" ]; then
  lock_pid="$(readlink "$lock" 2>/dev/null || true)"
  lock_pid="${lock_pid##*-}"
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    echo "signage.sh: ブラウザがすでに起動しています（PID $lock_pid）。" >&2
    echo "  開いているウィンドウをすべて閉じてから、もう一度実行してください。" >&2
    echo "  そのまま起動すると、キオスク表示にならず普通のタブが開くだけになります。" >&2
    exit 1
  fi
fi

# ---------- 画面を探す ----------
# SSH から叩くと DISPLAY も WAYLAND_DISPLAY も無いので、標準的な値を補う。
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export XDG_RUNTIME_DIR
fi
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -e "$XDG_RUNTIME_DIR/wayland-0" ]; then
  export WAYLAND_DISPLAY=wayland-0
fi
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ -e "/tmp/.X11-unix/X0" ]; then
  export DISPLAY=:0
fi

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  platform="wayland"
elif [ -n "${DISPLAY:-}" ]; then
  platform="x11"
else
  echo "signage.sh: 表示先の画面が見つかりません。" >&2
  echo "  デスクトップにログインした状態で実行してください。" >&2
  echo "  SSH から起動する場合は、先に WAYLAND_DISPLAY か DISPLAY を設定してください。" >&2
  exit 1
fi

# ---------- 画面が消えないようにする ----------
if [ "$platform" = "x11" ] && command -v xset >/dev/null 2>&1; then
  xset s off -dpms s noblank >/dev/null 2>&1 || true
elif [ "$platform" = "wayland" ]; then
  # Wayland ではスクリーンブランクをアプリ側から止められない。
  echo "signage.sh: 画面の自動消灯は raspi-config で切ってください" >&2
  echo "  sudo raspi-config -> Display Options -> Screen Blanking -> No" >&2
fi

# ---------- 前回の異常終了を引きずらない ----------
# 電源を落として終わる運用だと、次の起動で「復元しますか」が出て画面を塞ぐ。
prefs="$config_dir/Default/Preferences"
if [ -f "$prefs" ]; then
  sed -i 's/"exit_type":"[^"]*"/"exit_type":"Normal"/' "$prefs" 2>/dev/null || true
fi

# ---------- 起動 ----------
flags=(
  "--ozone-platform=$platform"
  --password-store=basic
  --no-first-run
  --no-default-browser-check
  --noerrdialogs
  --disable-infobars
  --disable-session-crashed-bubble
  --disable-features=Translate,TranslateUI
  --disable-component-update
  --check-for-update-interval=31536000
  --autoplay-policy=no-user-gesture-required
  --overscroll-history-navigation=0
)
if [ -n "$profile" ]; then
  mkdir -p "$profile"
  flags+=("--user-data-dir=$profile")
fi
if [ "$kiosk" -eq 1 ]; then
  flags+=(--kiosk)
else
  flags+=(--window-size=1280,720)
fi

echo "signage.sh: $browser ($platform) で起動します"
echo "  ページ         : $page"
if [ -n "$profile" ]; then
  echo "  プロファイル   : $profile"
fi
if [ "$kiosk" -eq 1 ]; then echo "  終了           : Ctrl+C、または表示中に Alt+F4"; fi

exec "$browser" "${flags[@]}" "$@" "file://$page"
