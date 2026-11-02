---
name: triage
description: GitHub Issue の対応判断と、PR の調査・手直し・検証・マージを行う。PR 指定時は取り込みまで進めるのが既定。
---

# Issue / PR Triage

番号または URL から Issue / PR を判定する。

```text
/triage 12
/triage https://github.com/K9i-0/multi_device_preview/pull/12
/triage 12 内容だけ教えて
```

## 既定動作

- **PR を指定されたら、必要な修正・検証をこちらで引き受け、マージとお礼コメントまで進める。** 判断や推奨だけで止めず、同じ取り込み許可を再確認しない。
- 「内容だけ」「レビューだけ」「まだマージしない」など明示された範囲を優先する。スキル自体の相談・改善は、例示された PR の取り込み依頼ではない。
- Issue 単独は対応判断を返す。実装は依頼範囲に含まれる場合に進める。
- ラベルやテンプレートの充足を調査開始・採用の条件にしない。
- 実装・テストを AI に任せることは問題にしない。投稿者が示した目的、方針の判断、実際の検証結果と限界を確認する。
- 不足テスト、小さな設計調整、競合は原則こちらで処理する。重大な目的不一致や取り込みに見合わない再実装は、具体的な理由を示して見送る。
- マージとリリースは別の操作。リリースは依頼されたときに `release` スキルで行う。

## 種別判定と参照

URL 指定ならそのリポジトリを使う。番号のみなら現在のリポジトリを使う。API エラーを PR 扱いしない。

```bash
gh api "repos/{owner}/{repo}/issues/<number>" \
  --jq '{number,title,body,labels:[.labels[].name],state,author:.user.login,isPR:(.pull_request != null)}'
```

- Issue: [references/issue.md](references/issue.md)
- PR: [references/pr.md](references/pr.md)
- マージ後のお礼、または依頼されたコメント: [references/comments.md](references/comments.md)
