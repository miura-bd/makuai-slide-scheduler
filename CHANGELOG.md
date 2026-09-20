# 変更履歴

このファイルの書き方は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に、
バージョンの付け方は [セマンティック バージョニング](https://semver.org/lang/ja/) に従います。

## [未リリース]

## [1.0.1] - 2026-09-20

動作の変更はありません。初めて使う人が手順どおりに進めない箇所があったため、
そこを埋めたドキュメントの修正です。

### 修正

- 起動手順に、ターミナルで展開したフォルダへ移動する指示がなかった。
  ホームディレクトリで `./signage.sh` を叩くと `No such file or directory` で止まる
- 実行権限が落ちた場合の復旧手順（`chmod +x`）がなかった。
  Windows 経由や USB メモリ経由でコピーすると起こる
- キオスク表示の終了方法が macOS と Windows にだけ書かれており、Linux が抜けていた

### 変更

- README のヒーロー画像に埋め込んだデモスライドが Raspberry Pi 専用に見える
  内容だったため、環境に寄らない一般的な登壇タイトルに差し替えた
- 時計合わせの説明が Linux 前提だったので、macOS / Windows は自動同期であること、
  RTC を持たないのは Raspberry Pi だけであることを分けて書いた
- 既知の制限を「制約」に明記した。日付をまたぐスケジュールに対応していないこと、
  Windows 版の起動スクリプトが実機未検証であること

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

[未リリース]: https://github.com/miura-bd/makuai-slide-scheduler/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/miura-bd/makuai-slide-scheduler/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/miura-bd/makuai-slide-scheduler/releases/tag/v1.0.0
