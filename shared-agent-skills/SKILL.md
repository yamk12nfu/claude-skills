---
name: shared-agent-skills
last-verified: 2026-07-19
description: 複数のコーディングエージェント（Claude Code, OpenAI Codex, Cursor, VS Code等）でSkillsを共有するためのセットアップを行う。「スキルを共有したい」「Claude CodeとCodexの両方で使えるようにしたい」「.agents/skills を設定したい」「エージェント間でスキルを共有」「マルチエージェント対応」「AGENTS.mdとCLAUDE.mdを同期したい」といった要求で使用する。
---

# Shared Agent Skills

`.agents/skills/` に実体を配置し、Claude Code からはシンボリックリンクで参照する構成をセットアップする。

## 対応エージェントとディレクトリ

| Agent | Skills Directory | 参照方法 |
|-------|-----------------|----------|
| OpenAI Codex | `.agents/skills/` | 直接読み込み |
| Claude Code | `.claude/skills/` | `.agents/skills/` への symlink |
| VS Code (Copilot) | `.claude/skills/` | symlink 経由 |
| Cursor (Nightly) | `.claude/skills/` | symlink 経由 (Import Agent Skills設定) |

## 目標構成

```
project-root/
├── .agents/skills/             # 実体（Codex はここを直接読む）
│   ├── frontend-dev/SKILL.md
│   ├── backend-dev/SKILL.md
│   └── testing/SKILL.md
├── .claude/skills → ../.agents/skills  # symlink (Claude Code 用)
├── AGENTS.md                   # ガイドライン実体（任意）
└── CLAUDE.md → AGENTS.md       # symlink（任意）
```

## セットアップ

同梱の `scripts/setup.sh` を実行する。

### 基本セットアップ

```bash
bash <skill-path>/scripts/setup.sh
```

以下を実行する:
1. `.agents/skills/` ディレクトリを作成
2. `.claude/skills` → `../.agents/skills` シンボリックリンクを作成

### AGENTS.md / CLAUDE.md も同期する場合

```bash
bash <skill-path>/scripts/setup.sh --with-agents-md
```

追加で以下を実行する:
- 既存の `CLAUDE.md` があれば `AGENTS.md` にリネーム
- `CLAUDE.md` → `AGENTS.md` のシンボリックリンクを作成

### 既存スキルのマイグレーション

```bash
bash <skill-path>/scripts/setup.sh --migrate
```

`.claude/skills/` や `.codex/skills/` に既にスキルがある場合、`.agents/skills/` へ移動してからシンボリックリンクを張る。

### ドライラン

```bash
bash <skill-path>/scripts/setup.sh --dry-run
```

実際には変更せず、何が行われるかを表示する。

### オプション組み合わせ例

```bash
# 全部入り（ドライランで確認してから実行）
bash <skill-path>/scripts/setup.sh --migrate --with-agents-md --dry-run
bash <skill-path>/scripts/setup.sh --migrate --with-agents-md
```

## セットアップ後の手順

### 1. スキルを追加

`.agents/skills/` にスキルディレクトリを作成する。各スキルは `SKILL.md` を含む:

```
.agents/skills/my-skill/
└── SKILL.md
```

SKILL.md のフォーマット:

```yaml
---
name: my-skill
description: スキルの説明（トリガー条件を含む）
---

# My Skill

（スキルの指示内容）
```

### 2. AGENTS.md にスキル一覧を記載（推奨）

```markdown
## Available Skills

| Skill | Description |
|-------|-------------|
| frontend-dev | フロントエンド開発のガイドライン |
| backend-dev | バックエンド開発のガイドライン |
| testing | テスト方針のガイドライン |
```

### 3. Git にコミット

```bash
git add .agents/ .claude/skills
git add AGENTS.md CLAUDE.md  # --with-agents-md を使った場合
git commit -m "Setup shared agent skills structure"
```

Git はシンボリックリンクをそのまま追跡するため、チームメンバーが clone しても構成が維持される。

## 動作確認

- **Claude Code**: `claude` 起動後 `/skills` で一覧表示
- **OpenAI Codex**: `codex` 起動後 `$` 入力で一覧表示

## 注意事項

- SKILL.md フォーマットは Claude Code と Codex で共通（YAML frontmatter + Markdown）
- 既存の `.claude/skills` が実ディレクトリの場合、先に `--migrate` でマイグレーションすること
