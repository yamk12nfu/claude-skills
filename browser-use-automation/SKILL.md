---
name: browser-use-automation
last-verified: 2026-07-19
description: browser-use CLIを使ったブラウザ操作の自動化スキル（Playwright MCPは使わない）。Webページの閲覧・スクリーンショット撮影、フォーム入力・ボタンクリック等のブラウザ操作、Webページからの情報収集・データ抽出を行い、スクリーンショット・抽出データ・操作ログをプロジェクト内フォルダに保存する。「ブラウザで○○を開いて」「○○のスクリーンショットを撮って」「○○にログインして」「Webページから○○を取得して」「ブラウザ操作して」「browser-useで」「スクレイピングして」「Webの情報を集めて」といった指示で使用する。すべてのブラウザ操作はBashツール経由でbrowser-use CLIコマンドを実行すること。mcp__playwright__系ツールは絶対に使用しないこと。
---

# Browser Use Automation

`browser-use` CLIでブラウザを操作し、スクリーンショット・抽出データ・操作ログをプロジェクト内に保存する。

**重要: このスキルではすべてのブラウザ操作を `browser-use` CLI（Bashツール経由）で行う。Playwright MCPツール（`mcp__playwright__*`）は使用しないこと。** ブラウザの操作・スクリーンショット・データ抽出はすべて以下の `browser-use` コマンドで実行する。

## セットアップ確認

タスク開始前に以下を確認:

```bash
/Users/makinokaedenari/.browser-use-env/bin/browser-use doctor
```

以降のコマンド例では `browser-use` と省略するが、実際には上記フルパスを使用すること。

## ワークフロー

### 1. セッション初期化

出力先ディレクトリを作成する。ユーザーが保存先を指定した場合はそれを使用、未指定なら `./browser-results/` をデフォルトとする。

```bash
# デフォルト保存先
SESSION_DIR=$(bash /Users/makinokaedenari/.claude/skills/browser-use-automation/scripts/init-session.sh)

# ユーザー指定の保存先
SESSION_DIR=$(bash /Users/makinokaedenari/.claude/skills/browser-use-automation/scripts/init-session.sh ./my-output "my-session")
```

これにより以下が作成される:
```
<session_dir>/
├── screenshots/     # スクリーンショット保存先
├── data/            # 抽出データ保存先
└── operation.log.md # 操作ログ
```

### 2. ブラウザ操作

#### ページを開く

```bash
browser-use open "https://example.com"
```

ログイン状態を維持したい場合は `--session` を付与:

```bash
browser-use --session my-task open "https://example.com"
```

実際のChromeプロファイル（ログイン済み状態）を使いたい場合:

```bash
browser-use --profile open "https://example.com"
```

#### ページ状態の取得

`state` で操作可能な要素一覧とインデックスを取得:

```bash
browser-use state
```

出力例:
```
URL: https://example.com
Title: Example Domain
Interactive elements:
[0] <a>More information...</a>
[1] <input type="text" name="search">
[2] <button>Submit</button>
```

#### 要素操作

`state` で得たインデックスを使用:

```bash
browser-use click 0              # インデックス0の要素をクリック
browser-use input 1 "search text" # インデックス1に入力
browser-use click 2              # ボタンをクリック
browser-use select 3 "option1"   # ドロップダウン選択
browser-use keys Enter           # Enterキー送信
browser-use scroll down          # ページ下スクロール
```

#### 操作ごとのログ記録

各操作後に `append-log.sh` でログを記録:

```bash
bash /Users/makinokaedenari/.claude/skills/browser-use-automation/scripts/append-log.sh \
  "$SESSION_DIR" "open https://example.com" "ページを開いた" "ok"
```

### 3. スクリーンショット保存

操作の各ステップでスクリーンショットを保存する。ファイル名は操作内容がわかる命名にする:

```bash
browser-use screenshot "${SESSION_DIR}/screenshots/01_initial.png"
browser-use screenshot "${SESSION_DIR}/screenshots/02_after_login.png"
browser-use screenshot "${SESSION_DIR}/screenshots/03_result.png" --full  # フルページ
```

保存後、Read toolでスクリーンショットを読み込みユーザーに表示すること。

### 4. データ抽出・保存

#### LLMベース抽出

```bash
browser-use extract "このページの全商品名と価格をJSON形式で" > "${SESSION_DIR}/data/products.json"
```

#### JavaScript抽出

```bash
browser-use eval "JSON.stringify(Array.from(document.querySelectorAll('table tr')).map(r => Array.from(r.cells).map(c => c.textContent)))" > "${SESSION_DIR}/data/table.json"
```

抽出したデータは `${SESSION_DIR}/data/` に保存する。

### 5. セッション終了

操作完了後、ログにサマリーを追記してブラウザを閉じる:

```bash
# 操作ログの末尾にサマリーを追加（EOFはクォートしない: $(date)を展開させるため）
cat >> "${SESSION_DIR}/operation.log.md" << EOF

## Summary

- **Completed**: $(date '+%Y-%m-%d %H:%M:%S')
- **Screenshots**: <保存したスクリーンショット数を記入>
- **Data files**: <保存したデータファイル数を記入>
EOF

browser-use close
```

最後に操作ログとスクリーンショットの場所をユーザーに報告する。

## 注意事項

- `state` は操作前に必ず実行し、要素インデックスを最新化すること（ページ遷移後はインデックスが変わる）
- ページ読み込みを待つ必要がある場合は `browser-use wait` を使用
- 認証が必要なサイトでは `--profile` で既存のChromeプロファイルを使うか、`--session` でセッション永続化を活用
- コマンドリファレンスの詳細: [references/commands.md](references/commands.md)
