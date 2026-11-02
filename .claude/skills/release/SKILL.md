---
name: release
description: multi_device_preview / multi_device_preview_marionette を pub.dev にリリースする（バージョン bump・CHANGELOG・タグ push → GitHub Actions で publish）。「リリースして」と言われたときに使う。
---

# pub.dev リリース

パッケージごとのタグを push すると `.github/workflows/publish.yml` が検証と pub.dev への publish（GitHub OIDC）を行う。

```text
/release                         # 差分のあるパッケージを判定してリリース
/release multi_device_preview    # 対象を指定
/release multi_device_preview 1.1.0
```

## 既定動作

- リリースの依頼そのものがコミット・`main` への push・タグ push の指示。追加の承認を求めない。
- 指定済みのパッケージ・バージョンを優先する。未指定の項目は下の規則で決め、決めた内容と理由を報告して進める。
- major に上げる場合だけ、具体的なバージョンと互換性への影響を示して AskUserQuestion で確認する。
- 手動の `flutter pub publish` はしない。公開はタグ経由だけ。

| パッケージ | ディレクトリ | タグ |
| --- | --- | --- |
| `multi_device_preview` | `packages/multi_device_preview` | `multi_device_preview-v<version>` |
| `multi_device_preview_marionette` | `packages/multi_device_preview_marionette` | `multi_device_preview_marionette-v<version>` |

## 1. 前提の確認

```bash
git switch main && git pull --ff-only
git status --short   # 未コミットの変更がないこと
```

未コミットの変更があれば、リリースに含めるべきものか確認してから進める。

## 2. 前回リリースからの差分

各パッケージについて、前回リリースの基点を決めて差分を見る。

```bash
pkg=multi_device_preview   # または multi_device_preview_marionette
dir=packages/$pkg

# 公開中のバージョンと公開日時
curl -s https://pub.dev/api/packages/$pkg | python3 -c 'import json,sys; l=json.load(sys.stdin)["latest"]; print(l["version"], l["published"])'
grep '^version:' $dir/pubspec.yaml

# 基点: 前回のタグ。なければ（1.0.0 はタグなしで手動公開）pub.dev の公開日時より前の最後の main のコミット
base=$(git tag -l "$pkg-v*" --sort=-v:refname | head -1)
if [ -z "$base" ]; then
  published=$(curl -s https://pub.dev/api/packages/$pkg | python3 -c 'import json,sys; print(json.load(sys.stdin)["latest"]["published"])')
  base=$(git rev-list -1 --before="$published" origin/main)
fi
git log --oneline "$base"..HEAD -- $dir
```

- `multi_device_preview` のディレクトリには `example/` も含まれる。example だけの変更はリリース理由にならない（pub.dev の表示には出るので、README・example の修正だけでも公開したいなら patch でよい）。
- パッケージ未指定で、差分がテスト・CI・リポジトリ文書だけのパッケージはリリースしない。どちらにも差分がなければその旨を報告して終える。
- 両方リリースするときは `multi_device_preview` → `multi_device_preview_marionette` の順に行う。

## 3. バージョンの決定

[Dart のバージョニング](https://dart.dev/tools/pub/versioning) に従う（1.0.0 以降なので通常の semver）。

- 公開 API の削除・シグネチャ変更・挙動の互換性破壊（`!` / `BREAKING CHANGE` を含む）→ major。確認が必要。
- `feat` / 公開 API の追加 → minor
- それ以外の修正・改善・依存更新 → patch

## 4. CHANGELOG と pubspec

`$dir/CHANGELOG.md` の先頭に、既存と同じ形式で節を追加する。**見出しは `## X.Y.Z` だけにする**（角括弧や日付を付けない）。publish.yml が `^## X.Y.Z$` に一致する行を確認し、なければ失敗する。

```markdown
## 1.1.0

- Add ...
- Fix ...
```

- 利用者から見た変化を英語で書く。内部のリファクタリング・テスト・CI は書かない。
- 既に未リリースの項目（バージョン未定の節）があれば、その内容を新しい節にまとめる。

`$dir/pubspec.yaml` の `version:` を更新する。

`multi_device_preview` を minor / major で上げ、アダプターが新しい API を使う場合は、`packages/multi_device_preview_marionette/pubspec.yaml` の `multi_device_preview: ^X.Y.0` も上げ、アダプターも続けてリリースする。

## 5. ローカル検証

publish.yml と同じ検証を行う。すべて通らなければタグを打たない。

```bash
mise run setup
mise run check
mise run publish-check
(cd packages/multi_device_preview/example && flutter build macos --debug)
```

`publish-check` の警告（`Package has 0 warnings` 以外）は内容を確認し、今回の変更に起因するものは直す。

## 6. コミットとタグ

```bash
git add $dir/pubspec.yaml $dir/CHANGELOG.md   # アダプターの依存制約を変えたらそれも
git commit -m "chore: release $pkg X.Y.Z"
git push origin main
git tag $pkg-vX.Y.Z
git push origin $pkg-vX.Y.Z
```

両パッケージを出すときは、コミットはまとめてよい（`chore: release multi_device_preview X.Y.Z and multi_device_preview_marionette A.B.C`）。タグは本体を先に push し、その publish が成功して pub.dev に反映されてからアダプターのタグを push する（アダプターの publish は pub.dev 上の本体を解決するため）。

## 7. 完了確認

```bash
gh run list --workflow=publish.yml --limit 2
gh run watch <run-id> --exit-status
curl -s https://pub.dev/api/packages/$pkg | python3 -c 'import json,sys; print(json.load(sys.stdin)["latest"]["version"])'
```

pub.dev の `latest.version` が新しいバージョンになれば完了。パッケージページの URL（`https://pub.dev/packages/<pkg>`）と、リリースしたバージョン・主な変更を報告する。

### 失敗したとき

- **バージョン・CHANGELOG の不一致**（`Resolve the package from the tag` で失敗）: 修正をコミット・push し、タグを付け直す（`git push origin :refs/tags/<tag>` → `git tag -f <tag>` → `git push origin <tag>`）。pub.dev にまだ公開されていないことを確認してから行う。
- **check / build の失敗**: 原因を直してから同様にタグを付け直す。
- **Publish ステップの認証エラー**: pub.dev 側の設定（パッケージの Admin で verified publisher `k9i.app` への移管と、Automated publishing をリポジトリ `K9i-0/multi_device_preview`・タグパターン `<pkg>-v{{version}}` で有効化）が未完了の可能性が高い。ユーザーに必要な設定を伝え、設定後に `gh run rerun <run-id>` する。手動 publish で代替しない。
- 一度 pub.dev に公開されたバージョンは取り消せない。公開後に問題が見つかったら次の patch で直す。
