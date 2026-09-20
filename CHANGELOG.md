# 変更履歴

このファイルの書き方は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に、
バージョンの付け方は [セマンティック バージョニング](https://semver.org/lang/ja/) に従います。

## [未リリース]

## [1.0.0] - 2026-09-20

最初のリリース。

### 追加

- 登壇スケジュールに合わせて Google スライドを自動で切り替えるサイネージ表示（`index.html` 1枚）
- 切り替えバッファ。登壇開始から少し経ってから次の予告に移るので、開始が押しても予告が消えない
- 設定したタイムゾーンでの時刻判定。端末のタイムゾーン設定に依存しない
- 進行補正。`←` `→` で 5 分ずつずらして押し / 巻きを吸収する。補正値は端末ごとに保存される
- スライド未設定の枠を登壇者カードで埋める代替表示
- キー操作（`1`〜`9` 固定 / `0` 自動に戻す / `S` 設定 / `R` 再読み込み / `H` 状態表示）
- 設定の書き出し / 読み込み（JSON）
- `?config=` による外部 JSON の読み込み（HTTP 配信時）
- 保存時の入力検証。読めない時刻、`25:00` のような存在しない時刻、
  認識できないタイムゾーン名を弾き、該当の入力欄に印を付ける
- 起動スクリプト。Linux / Raspberry Pi OS は `signage.sh`、macOS は `signage.command`、
  Windows は `signage.cmd`

[未リリース]: https://github.com/miura-bd/makuai-slide-scheduler/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/miura-bd/makuai-slide-scheduler/releases/tag/v1.0.0
