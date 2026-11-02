## コメント言語と投稿

- 英語の投稿には英語だけで返信する。
- 英語以外には元の言語を先に書き、`---` の後に英語を付ける。
- 複数段落は一時ファイルを `--body-file` で渡す。
- 投稿後に取得し直し、Markdown を確認する。

```bash
gh pr comment <number> --body-file /tmp/multi-device-preview-pr-comment.md
gh issue comment <number> --body-file /tmp/multi-device-preview-issue-comment.md
```
