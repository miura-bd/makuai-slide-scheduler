#!/usr/bin/env bash
#
# makuai-slide-scheduler をサイネージモードで起動する。
#
#   ./signage.sh             キオスク表示で起動する（本番）
#   ./signage.sh --windowed  ウィンドウで起動する（設定や本番前の確認用）
#   ./signage.sh --help
#
# Linux（Raspberry Pi OS を含む）と macOS で動く。Windows は signage.cmd を使う。
# `--` 以降の引数はブラウザにそのまま渡す。
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
page="$here/index.html"
# 既定ではブラウザ本来のプロファイルを使う。index.html を開いて登録した内容を、
# そのままサイネージ表示に出すため。MAKUAI_PROFILE を指定したときだけ分ける。
profile="${MAKUAI_PROFILE:-}"
kiosk=1

usage() {
  cat <<'USAGE'
makuai-slide-scheduler をサイネージモードで起動します。

  ./signage.sh              キオスク表示で起動する（本番）
  ./signage.sh --windowed   ウィンドウで起動する（設定や本番前の確認用）
  ./signage.sh -- <引数...>  以降をブラウザにそのまま渡す

環境変数:
  MAKUAI_BROWSER   使うブラウザの実行ファイルを明示する
  MAKUAI_PROFILE   プロファイルを専用のものに分けたいときに指定する

登壇スケジュールの登録は index.html を開いて行ってください。
既定のブラウザが Chrome / Edge / Chromium でない場合（Safari など）は、
--windowed で開いて登録してください。設定はブラウザごとに別で保存されます。
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --windowed) kiosk=0; shift ;;
    --)         shift; break ;;
    *)          echo "signage.sh: 不明な引数: $1" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -f "$page" ]; then
  echo "signage.sh: index.html が見つかりません: $page" >&2
  echo "  このスクリプトは index.html と同じ場所に置いてください。" >&2
  exit 1
fi

case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin) os="macos" ;;
  *)      os="linux" ;;
esac

# ---------- ブラウザを探す ----------
# 見つけた実行ファイルと、そのブラウザが設定を置く場所を組で決める。
browser=""
config_dir=""

try_mac() {   # $1=実行ファイル  $2=設定の置き場所
  if [ -z "$browser" ] && [ -x "$1" ]; then browser="$1"; config_dir="$2"; fi
}
try_linux() { # $1=コマンド名    $2=設定の置き場所
  if [ -z "$browser" ] && command -v "$1" >/dev/null 2>&1; then browser="$1"; config_dir="$2"; fi
}

# 設定はブラウザごとに別なので、index.html をダブルクリックしたブラウザと
# ここで選ぶブラウザが食い違うと、登録した内容が出てこない。既定のブラウザが
# Chrome 系なら、それを最優先にする。
default_browser_id() {
  if [ "$os" = "macos" ]; then
    defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers 2>/dev/null |
      awk 'BEGIN { RS = "}" }
           /LSHandlerURLScheme = http;/ {
             if (match($0, /LSHandlerRoleAll = "[^"]+"/)) {
               print tolower(substr($0, RSTART + 20, RLENGTH - 21)); exit
             }
           }'
  else
    xdg-settings get default-web-browser 2>/dev/null
  fi
}

prefer=""
case "$(default_browser_id)" in
  *chrome*|*chromium*) prefer="chrome" ;;   # org.chromium.chromium も含む
  *edge*)              prefer="edge" ;;
esac

find_chrome() {
  if [ "$os" = "macos" ]; then
    try_mac "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"      "$support/Google/Chrome"
    try_mac "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "$support/Google/Chrome"
    try_mac "/Applications/Chromium.app/Contents/MacOS/Chromium"                "$support/Chromium"
  else
    try_linux chromium             "$HOME/.config/chromium"
    try_linux chromium-browser     "$HOME/.config/chromium"
    try_linux chromium-bin         "$HOME/.config/chromium"
    try_linux google-chrome-stable "$HOME/.config/google-chrome"
    try_linux google-chrome        "$HOME/.config/google-chrome"
  fi
}

find_edge() {
  if [ "$os" = "macos" ]; then
    try_mac "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"      "$support/Microsoft Edge"
    try_mac "$HOME/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" "$support/Microsoft Edge"
  else
    try_linux microsoft-edge "$HOME/.config/microsoft-edge"
  fi
}

support="$HOME/Library/Application Support"
if [ -n "${MAKUAI_BROWSER:-}" ]; then
  browser="$MAKUAI_BROWSER"
elif [ "$prefer" = "edge" ]; then
  find_edge; find_chrome
else
  find_chrome; find_edge
fi

if [ -z "$browser" ]; then
  echo "signage.sh: Chrome / Edge / Chromium が見つかりません。" >&2
  if [ "$os" = "macos" ]; then
    echo "  Google Chrome を入れるか、MAKUAI_BROWSER で実行ファイルを指定してください。" >&2
  else
    echo "  Raspberry Pi OS なら: sudo apt install -y chromium-browser" >&2
  fi
  exit 1
fi

# プロファイルを明示された場合は、そちらを設定の置き場所として扱う
if [ -n "$profile" ]; then config_dir="$profile"; fi

# ---------- すでに開いているブラウザがあると、キオスクにならない ----------
# 同じプロファイルで起動中だと、ブラウザは新しいウィンドウを既存のプロセスに
# 任せてしまい、--kiosk が効かずに普通のタブが開くだけになる。
if [ -n "$config_dir" ] && [ -L "$config_dir/SingletonLock" ]; then
  lock_pid="$(readlink "$config_dir/SingletonLock" 2>/dev/null || true)"
  lock_pid="${lock_pid##*-}"
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    echo "signage.sh: ブラウザがすでに起動しています（PID $lock_pid）。" >&2
    echo "  開いているウィンドウをすべて閉じてから、もう一度実行してください。" >&2
    echo "  そのまま起動すると、キオスク表示にならず普通のタブが開くだけになります。" >&2
    exit 1
  fi
fi

# ---------- 画面を用意する ----------
prefix=()
flags=()

if [ "$os" = "linux" ]; then
  # SSH から叩くと DISPLAY も WAYLAND_DISPLAY も無いので、標準的な値を補う。
  if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"; export XDG_RUNTIME_DIR
  fi
  if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -e "$XDG_RUNTIME_DIR/wayland-0" ]; then
    export WAYLAND_DISPLAY=wayland-0
  fi
  if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ -e "/tmp/.X11-unix/X0" ]; then
    export DISPLAY=:0
  fi

  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    display="wayland"
  elif [ -n "${DISPLAY:-}" ]; then
    display="x11"
  else
    echo "signage.sh: 表示先の画面が見つかりません。" >&2
    echo "  デスクトップにログインした状態で実行してください。" >&2
    echo "  SSH から起動する場合は、先に WAYLAND_DISPLAY か DISPLAY を設定してください。" >&2
    exit 1
  fi
  flags+=("--ozone-platform=$display" --password-store=basic)

  # 画面が消えないようにする
  if [ "$display" = "x11" ] && command -v xset >/dev/null 2>&1; then
    xset s off -dpms s noblank >/dev/null 2>&1 || true
  elif [ "$display" = "wayland" ]; then
    # Wayland ではスクリーンブランクをアプリ側から止められない。
    echo "signage.sh: 画面の自動消灯は raspi-config で切ってください" >&2
    echo "  sudo raspi-config -> Display Options -> Screen Blanking -> No" >&2
  fi
else
  display="macos"
  # 表示中だけスリープとディスプレイオフを抑える
  if command -v caffeinate >/dev/null 2>&1; then prefix=(caffeinate -dis); fi
fi

# ---------- 前回の異常終了を引きずらない ----------
# 電源を落として終わる運用だと、次の起動で「復元しますか」が出て画面を塞ぐ。
if [ -n "$config_dir" ] && [ -f "$config_dir/Default/Preferences" ]; then
  sed -i.bak 's/"exit_type":"[^"]*"/"exit_type":"Normal"/' \
    "$config_dir/Default/Preferences" 2>/dev/null || true
  rm -f "$config_dir/Default/Preferences.bak" 2>/dev/null || true
fi

# ---------- 起動 ----------
flags+=(
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

why=""
if [ -n "${MAKUAI_BROWSER:-}" ]; then why="  ← MAKUAI_BROWSER の指定"
elif [ -n "$prefer" ];            then why="  ← 既定のブラウザ"
fi
echo "signage.sh: $browser ($display) で起動します$why"
echo "  ページ         : $page"
if [ -n "$profile" ]; then
  echo "  プロファイル   : $profile"
fi
if [ "$kiosk" -eq 1 ]; then echo "  終了           : Ctrl+C、または表示中に Alt+F4 / Cmd+Q"; fi

# macOS の /bin/bash は 3.2 で、set -u のもとでは空配列の展開が落ちる。
exec ${prefix[@]+"${prefix[@]}"} "$browser" "${flags[@]}" "$@" "file://$page"
