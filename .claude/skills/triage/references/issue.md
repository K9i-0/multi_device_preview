# Issue フロー

## 情報収集

- タイトル、本文、ラベル、コメントから Bug / Feature / Question を判定する。
- 再現手順、期待結果、実際の結果、環境（macOS・Flutter のバージョン、使っているプリセット・文字サイズ）、ログを確認する。
- 関連コードはキーワードと機能単位で絞って調査する。同期まわりは先に `docs/design_notes.md` のはまりどころを読む。
- 既存機能、重複 Issue、上流（device_preview・Flutter・marionette_flutter）起因を確認する。

## 対象範囲の判定

- 対象: macOS ホストでのプレビュー、入力同期、ツールバー・端末ごとの設定、コマンド・VM service 拡張、`init` コマンド、Marionette アダプター。
- 設計上の対象外: macOS 以外のホスト、ネイティブ UI・WebView・動画・ソフトウェアキーボード、実機と同等の再現（描画は全端末 iOS 扱い）。理由を示して `wontfix` を検討する。
- 上流起因: 外枠・機種プリセットの不具合は device_preview、Marionette 本体の挙動は marionette_flutter へ案内する。こちらで回避できるなら回避策も検討する。
- 対象アプリ固有の構成（状態管理・Navigator・グローバルな singleton など）で同期が崩れる場合は、設計ノートの前提と照らして、ドキュメントで案内するか対応するかを判断する。

## 難易度

| 難易度 | 基準 | 目安 |
| --- | --- | --- |
| Low | 単一ファイル、既存パターン | 〜1時間 |
| Medium | 複数ファイル、Widget / コマンドの拡張 | 数時間 |
| High | 同期の仕組み（anchor / mapping / mirror / text_sync / gate）の変更、公開 API の変更 | 1日以上 |
| Very High | アーキテクチャ、上流依存の置き換え、破壊的変更 | 数日以上 |

## Issue レポート

```markdown
## Triage Report: #<number> <title>

### 概要・種別
[要約]

### 推奨ラベル
- [labels]（`gh label list` にある既存のものから選ぶ）

### 既存機能・重複・上流
[結果]

### 実現難易度: [Low / Medium / High / Very High]
[根拠となるファイル、公開 API・CHANGELOG への影響、影響範囲]

### 対応判断
| 観点 | 評価 |
| --- | --- |
| ユーザー価値 | [高/中/低 — 理由] |
| 実装コスト | [高/中/低 — 理由] |
| リスク | [高/中/低 — 理由] |
| 推奨 | [対応 / 外部PR待ち / 保留 / 見送り] |

### 推奨アクション
- [具体的な次の手順]
```

## 種別ごとの補足

### Bug

- 再現性、影響範囲、回避策、上流起因を確認する。
- 可能なら example か最小の再現アプリで再現し、`mise run smoke` やテストで確認する。
- 再現できなければ `question` を付けて再現情報を求める。

### Feature

- 方向性（複数端末を並べて一度に確かめる、というツールの目的に合うか）、ユーザー価値、代替手段を確認する。
- 公開 API を増やすものは、互換性と保守コストを見る。

### Dependabot

- breaking changes、upstream changelog、CI を確認する。major update または device_preview・marionette_flutter の更新だけ深掘りする。
