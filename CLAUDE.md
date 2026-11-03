# multi_device_preview

Flutter アプリを複数の端末サイズ・文字サイズで 1 つの macOS ウィンドウに並べて動かし、1 台への操作を他の端末へ送る pub.dev パッケージ。ルートは pub workspace。

| パス | 内容 |
| --- | --- |
| `packages/multi_device_preview/` | 本体。プレビュー・入力同期・コマンド・`init` コマンド |
| `packages/multi_device_preview/example/` | macOS の example。`smoke/` と `marionette/` のエントリあり |
| `packages/multi_device_preview_marionette/` | コマンドを Marionette MCP のツールとして公開するアダプター |
| `docs/design_notes.md` | 設計方針とはまりどころ（同期の仕組み・対象外の範囲） |

## 作業と完了条件

- 依頼された変更に必要な実装・検証・不具合修正まで継続する。指定済みの対象や承認を繰り返し確認しない。
- `main` で直接作業・コミットし、確認なしで push する。PR は外部からの貢献だけで受ける。`main` への push では何も公開されない。
- 機能単位でコミットする。Conventional Commits（`feat:` / `fix:` / `docs:` / `chore:` など）を使う。scope は付けなくてよい。
- 同期の仕組み（anchor / position_mapping / input_mirror / text_sync / input_gate）を変えるときは先に `docs/design_notes.md` を読み、判断が変わったら同じ文書を更新する。
- 公開 API・挙動を変えたら、該当パッケージの `CHANGELOG.md` に次のバージョンの項目として残す（バージョン番号はリリース時に決める）。README・example も合わせる。

## 検証

Flutter は `.mise.toml` で固定している。`flutter` / `dart` は mise 経由のものを使い、タスクは `mise run` で実行する。

| コマンド | 内容 | 使う場面 |
| --- | --- | --- |
| `mise run setup` | workspace 全体の `flutter pub get` | 依存変更後・初回 |
| `mise run format` | `dart format packages` | コミット前 |
| `mise run check` | format-check・`dart analyze --fatal-infos`・全パッケージのテスト | Dart の変更すべて |
| `mise run publish-check` | 両パッケージの `flutter pub publish --dry-run` | pubspec・公開ファイル・README の変更、リリース前 |
| `mise run smoke` | example を macOS で動かし、アプリ内で撮ったスクリーンショットを `tmp/smoke/` に保存 | 表示・同期の挙動の変更 |
| `mise run example` | example を macOS で起動 | 手動確認 |

- 文書だけの変更は参照・リンク・形式を確認すればよい。
- 表示・入力同期を変えたら `mise run smoke` の画像を見て確認する。ディスプレイがスリープ中は `screencapture` が黒くなるので、外部からの撮影ではなく smoke を使う。
- Marionette 経由の操作は `packages/multi_device_preview/example/marionette/` のエントリで起動して確かめる。
- CI（`.github/workflows/ci.yml`）は `check`・`publish-check` と example の `flutter build macos --debug` を実行する。

## 対象範囲

- ホストは macOS のみ。描画は全端末 iOS 扱いで、Android のプリセットはサイズ・安全領域・外枠だけを変える。
- 実機検証の代わりではない。ネイティブ UI・WebView・動画・ソフトウェアキーボードは対象外。
- 外枠・機種プリセットは [device_preview](https://pub.dev/packages/device_preview) を使うが、その binding は使わない。外枠やプリセット自体の不具合は上流の問題。
- 例外として、上流にまだない機種（iPhone Duo）は `lib/src/presets.dart` の `MultiDevicePresets` に同梱する。外枠はおおよそでよい。上流に入ったら置き換える。

## Issue・PR とリリース

依頼された操作に対応するスキルを読む。

- Issue / PR の判断と取り込み: [.claude/skills/triage/SKILL.md](.claude/skills/triage/SKILL.md)
- pub.dev へのリリース: [.claude/skills/release/SKILL.md](.claude/skills/release/SKILL.md)
- 公開はパッケージごとのタグ（`multi_device_preview-v<version>` / `multi_device_preview_marionette-v<version>`）の push で `.github/workflows/publish.yml` が行う。タグはリリースを依頼されたときに release スキルの手順でだけ打つ。手動の `flutter pub publish` はしない。
- PR をマージしたら作者へお礼コメントを投稿する。この投稿は継続的に承認済み。形式は [.claude/skills/triage/references/comments.md](.claude/skills/triage/references/comments.md) に従う。
