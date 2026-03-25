---
name: implement-from-spec
description: 要件定義書（Markdown）から実装を完遂するオーケストレーターskill。要件定義書のパスを受け取り、ファイルベース計画 → subagent駆動開発の順で実装を進める。「要件定義書通りに実装して」「specから実装して」「requirements.mdを実装して」といった指示で使用する。コンテキスト消費を最小化しcompact耐性を確保する。
---

# Implement from Spec

要件定義書を読み、計画を立て、subagentで実装する。コンテキストはファイルに逃がし、実装は独立したsubagentに委譲する。

## Workflow

```
1. Validate spec  → 要件定義書の実装可否を検証
2. Read spec      → タスクを特定、グローバル制約を抽出
3. Plan to file   → task_plan.md に実装計画を書き出す
4. Execute        → タスクごとにsubagentを起動して実装
5. Finish         → 最終レビュー・ブランチ仕上げ
```

## Step 1: Validate Spec Readiness

要件定義書を読み、実装に進めるか検証する。requirements-definition skillの出力を想定。

### 1a. 未解決事項の検出

以下を確認し、該当があればユーザーに報告して判断を仰ぐ:

- **セクション8（未決事項・課題）** に未解決の項目がないか
- **TBD / TODO / 要検討** マーカーが残っていないか
- **セクション3.3（Should/Could項目）** が概要レベルのまま詳細化されていないか

### 1b. 実装スコープの決定

- **Must項目（セクション3.1/3.2）のみ**をデフォルトの実装対象とする
- Should/Could項目は、詳細な受入条件が記載されている場合のみ対象に含める
- 曖昧な要件は実装対象から除外し、ユーザーに報告する

**ユーザーへの報告フォーマット:**
```
実装対象: Must項目 N件
除外: Should/Could項目 N件（詳細未定）
未解決: N件（セクション8より）
→ このスコープで進めてよいですか？
```

ユーザーの承認を得てから次のステップへ進む。

### 1c. グローバル制約の抽出

要件定義書から以下のグローバル制約を抽出し、task_plan.mdに記録する。これらは**全subagentに共通で渡す**:

- **非機能要件**（セキュリティ、パフォーマンス、エラーハンドリング方針 — セクション5相当）
- **技術スタック・アーキテクチャ制約**（セクション6相当）
- **共通ルール**（命名規則、ディレクトリ構成、コーディング規約など）

## Step 2: Extract Tasks & Create Plan

### 2a. タスク分解

実装対象の機能をタスク単位に分解する:
- タスク間の依存関係を特定する
- 実行順序を決定する（依存のないものは先に）
- **タスク粒度の目安:** 1タスク = 1つのsubagentが30分以内で完了できる単位
- **全Must要件をタスクに対応付ける** — Traceability Matrixを作成し、各Must要件が少なくとも1つのタスクにマッピングされていることを確認する。マッピングされていないMust要件があれば、タスクを追加するかユーザーに報告する

### 2b. Plan file の作成

要件定義書と同じディレクトリに以下を作成し、**repo rootからの相対パス**を控えておく（以降 `<plan-dir>` と表記）:

- `<plan-dir>/task_plan.md` — タスク一覧・依存関係・進捗・グローバル制約
- `<plan-dir>/progress.md` — セッションログ・エラー記録

例: 要件定義書が `docs/spec/requirements.md` なら `<plan-dir>` = `docs/spec/`

**注意:** 以降のgitコマンドでは `:(top)` prefix を使い、cwdに依存しないようにする。

### task_plan.md のフォーマット

```markdown
# Implementation Plan

## Source
- Spec: [要件定義書のパス]

## Global Constraints
<!-- 全subagentに共通で渡す制約。specのセクション5（非機能要件）/セクション6（技術要件）から抽出 -->

### Non-Functional Requirements
<!-- specセクション5から抽出 -->
- [例: レスポンスタイム 200ms以内]
- [例: SQLインジェクション対策必須、入力値は全てバリデーション]
- [例: エラーは統一フォーマットで返却]

### Tech Stack & Architecture
<!-- specセクション6から抽出 -->
- [例: Next.js 14 App Router, TypeScript strict, PostgreSQL]
- [例: API は RESTful、認証は NextAuth.js]

### Coding Conventions
- [例: 命名規則、ディレクトリ構成ルール]

## Traceability Matrix
<!-- 各Must要件が少なくとも1つのタスクにマッピングされていることを保証する -->

| Must要件 | Spec参照 | 対応タスク | 実装状態 |
|----------|----------|-----------|---------|
| [例: ユーザー登録] | 3.1-FR-001 | Task 1 | pending |
| [例: ログイン認証] | 3.1-FR-002 | Task 2, Task 3 | pending |
<!-- 全Must要件を列挙。対応タスクが空の行があってはならない -->
<!-- 実装状態は対応タスクが「全て」completeになった時だけcompleteにする -->

## Tasks

### Task 1: [タスク名]
- **Status:** pending
- **Base SHA:** (実行時に記録)
- **Head SHA:** (完了時に記録)
- **Depends on:** なし
- **Spec section:** [要件定義書の該当セクション]
- **Acceptance criteria:**
  - [具体的な完了条件1]
  - [具体的な完了条件2]
- **Working directory:** [対象ディレクトリ]
- **Key files:** [関連ファイルのパス]

### Task 2: [タスク名]
- **Status:** pending
- **Base SHA:** (実行時に記録)
- **Head SHA:** (完了時に記録)
- **Depends on:** Task 1
...
```

## Step 3: Execute Tasks with Subagents

### Preflight: worktree cleanチェック（初回のみ）

最初のタスク開始前に、task_plan.md / progress.md 以外の未コミット変更がないことを確認:
```bash
git status --porcelain | grep -v '<plan-dir>/task_plan.md' | grep -v '<plan-dir>/progress.md'
```
出力がある場合はユーザーに報告し、stash / commit / discard の判断を仰ぐ。**クリーンになるまでタスク実行に進まない。**

タスクごとに以下を繰り返す:

### 3a. Update plan & record base SHA

タスク開始前にplan fileを更新し、管理コミットを作成してからbase SHAを記録する:

1. task_plan.md の該当タスクの **Status** を `in_progress` に変更
2. plan/progress fileの変更を**管理コミット**として分離:
   ```bash
   git add ':(top)<plan-dir>/task_plan.md' ':(top)<plan-dir>/progress.md'
   git commit -m "chore: update plan - Task N in_progress"
   ```
3. **この管理コミットの後に** base SHAを記録:
   ```bash
   git rev-parse HEAD
   ```
4. task_plan.md の該当タスクの **Base SHA** に書き込む（この書き込み自体は未コミットのまま — 次の管理コミットで回収）

### 3b. Implementer subagent を起動

Agent tool (general-purpose) で起動。プロンプトに以下を**全て埋め込む**:

1. **グローバル制約**（task_plan.mdのGlobal Constraintsセクション全文）
2. **タスクの説明**（task_plan.mdから該当部分の全文）
3. **要件定義書の該当セクション**（全文コピー）
4. **コンテキスト**（このタスクの位置づけ、先行タスクの結果）
5. **作業ディレクトリ・関連ファイルのパス**
6. **「作業完了時にコミットせよ。ただし `<plan-dir>/task_plan.md`, `<plan-dir>/progress.md` はコミットに含めないこと」という指示（実際のパスを埋め込む）**

**重要:**
- subagentにplan fileやspec fileを「読ませる」のではなく、必要な内容をpromptに**埋め込む**（ただしreviewerがrepo内の実装コードを読むのは必須）
- グローバル制約は**毎回必ず含める** — 省略するとセキュリティ・パフォーマンス要件違反が起きる
- implementerには**必ずコミットさせる**（後続のdiff取得に必要）

### 3c. Spec compliance review

別のsubagentで仕様準拠レビュー。プロンプトに含める:

- **タスクの説明とacceptance criteria**（task_plan.mdから該当タスクの全文） — reviewerが判定する範囲を限定するために必須
- 要件定義書の該当セクション（参考として全文。ただし「このタスクの範囲はacceptance criteriaに記載の範囲のみ」と明記する）
- **グローバル制約**（非機能要件・技術制約を含む）
- Implementerの報告内容
- 「コードを実際に読んで検証せよ。グローバル制約への準拠も確認せよ。**タスクのacceptance criteriaに含まれない機能が未実装でも指摘しないこと**」という指示

指摘があればimplementer subagentを再起動して修正・コミットさせ、再度spec reviewを実施する。**指摘がゼロになるまで繰り返す。**

### 3d. Code quality review

spec compliance が通ったら、コード品質レビュー。

まず**現時点のHEAD**を取得してタスクスコープdiffを作る（修正コミットを含む最終状態）:
```bash
git rev-parse HEAD   # → current head
git diff <base-sha> <current-head> -- ':(top,exclude)<plan-dir>/task_plan.md' ':(top,exclude)<plan-dir>/progress.md'
```

プロンプトに含める:
- 上記コマンドで得た**タスクスコープのdiff**（累積diffではない）
- タスクの概要

指摘があればimplementer subagentを再起動して修正・コミットさせた後、**3c（spec compliance review）から再実行する**。品質改善のリファクタが仕様や非機能要件を壊していないことを確認するため。**両レビューの指摘がゼロになるまで繰り返す。**

### 3e. Record final head SHA & update plan

全レビューが通った後:

1. 最終状態のHEADを記録:
   ```bash
   git rev-parse HEAD
   ```
2. task_plan.md を更新:
   - 該当タスクの **Head SHA** に最終コミットのSHAを書き込む
   - 該当タスクのステータスを `complete` に変更
   - **Traceability Matrixの該当Must要件について、対応タスクが全てcompleteなら実装状態を `complete` に更新**（1つのMust要件が複数タスクにまたがる場合、残タスクがあればまだcompleteにしない）
   - エラーがあれば progress.md に記録
3. plan/progress fileの変更を**管理コミット**として分離:
   ```bash
   git add ':(top)<plan-dir>/task_plan.md' ':(top)<plan-dir>/progress.md'
   git commit -m "chore: update plan - Task N complete"
   ```

### 3f. Next task

次のタスクへ。依存関係を確認し、前提タスクが完了していることを確認してから進む。

## Step 4: Final Review & Finish

全タスク完了後:

1. **Traceability Matrixの網羅性確認** — 全Must要件の実装状態が complete であることを確認。漏れがあればタスクを追加して実装する
2. **最終spec網羅性レビュー** — subagentを起動し、要件定義書のMust項目全文とTraceability Matrixを渡して、実装との網羅性を照合する。「各Must要件が実際にコードで実現されているか検証せよ」という指示を含める
3. **最終コード品質レビュー** — 全体を通したコードレビューsubagentを起動
4. task_plan.md の全タスクが complete、Traceability Matrixの全行が complete であることを確認
5. ユーザーに完了報告

## Critical Rules

- **曖昧な要件は実装しない** — Must項目で詳細が明確なもののみ実装する
- **グローバル制約は全subagentに渡す** — 省略は非機能要件違反の原因になる
- **implementerには必ずコミットさせる** — タスクスコープのdiff取得に必須
- **base SHAはタスク開始前、head SHAは全レビュー完了後に記録する** — 修正コミットを含む最終状態を反映
- **レビュー修正後は最新HEADでdiffを再取得してからレビューをやり直す**
- **subagentは直列に起動する** — 並列だとコンフリクトする
- **plan file・spec fileはsubagentに読ませず、内容をpromptに埋め込む** — ただしreviewerがrepo内の実装コードを読むのは必須
- **plan/progress fileのパスは `<plan-dir>/` で一貫させる** — git add, diff, status すべてで実パスを使う
- **plan fileは毎タスク後に更新する** — compact耐性
- **spec complianceレビューをスキップしない**
- **レビューで問題が見つかったら、修正 → 再レビューのループを回す**
- **タスク間でメインコンテキストが膨れたら、plan fileとprogress.mdを読み直して復帰する**
