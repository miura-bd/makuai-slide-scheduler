#!/usr/bin/env bash
# macOS でダブルクリックして起動するための入口。中身は signage.sh。
# 初回は Gatekeeper に止められるので、右クリック →「開く」で実行してください。
cd "$(dirname "$0")" || exit 1
./signage.sh "$@"
status=$?
if [ "$status" -ne 0 ]; then
  echo
  echo "エラーで終了しました。上のメッセージを確認してください。"
  read -r -p "Enter キーを押すと閉じます..." _
fi
exit "$status"
