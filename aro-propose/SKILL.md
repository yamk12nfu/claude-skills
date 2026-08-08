---
name: aro-propose
description: aro (ai-repo-ops) の Proposal Loop の提案フェーズ（PR①）を起動する。.ai/managed/prompts/propose.md の手順に委譲する薄いラッパーで、前提確認・専用ブランチ作成・完了確認だけを担う。「propose して」「提案を書いて」「aro の提案を作って」「改善提案を書いて」「Proposal Loop の提案側を回して」と言われた時に使用する。aro が導入された（.ai/project.yaml がある）リポジトリでのみ動作する。セッション終了時の気づきの走り書き収穫は knowledge-harvest の担当、採用済み提案の実装は aro-improve の担当なので、このスキルは使わない。
---

# aro-propose — Proposal Loop の提案フェーズ起動

aro の Proposal Loop の提案フェーズ（PR①）を起動する。全体像は対象 repo に配布された
docs（ai-repo-ops の `docs/proposal-loop.md`）にある。

**手順の正本はこの skill ではなく、対象 repo の `.ai/managed/prompts/propose.md` である。**
propose.md は `aro sync` でバージョン管理され、repo ごと・時期ごとに更新される。
この skill が手順の中身を複製すると distribution 更新のたびに腐るため、
skill が持つのは起動まわりの段取りだけとする。
この skill と propose.md の記述が食い違ったら、常に propose.md に従うこと。

## 1. 前提確認

- リポジトリ直下に `.ai/project.yaml` があるか確認する。無ければ aro 未導入なので、
  その旨を伝えて終了する（`aro init` を勝手に実行しない）。
- `.ai/managed/prompts/propose.md` があるか確認する。無ければ distribution が
  Proposal Loop 未対応の版なので、`aro sync` での更新が必要と伝えて終了する。
- `aro` の起動方法を repo ごとに確認する。PATH にあるとは限らない。package.json の
  scripts / devDependencies、CLAUDE.md 等の既存設定から、その repo で使われている
  起動方法（node 絶対パスでの直接起動など）を特定する。repo のパッケージマネージャに
  従うこと（npm 管理の repo に pnpm を持ち込まない）。

## 2. 前処理（clean worktree と専用ブランチ）

```bash
git status --short
```

- 出力が空でなければ停止し、開発者に確認する。勝手に stash・破棄・commit しない
  （提案 PR は proposals ファイルだけで構成される必要があり、無関係な変更の混入は
  guard とレビューの両方を汚す）。
- 空であれば専用ブランチを切る。default branch 上で直接作業しない:

```bash
git switch -c docs/ai-propose-<topic>
```

`<topic>` は提案テーマが分かる kebab-case にする。

## 3. 本体（propose.md へ委譲）

`.ai/managed/prompts/propose.md` を読み、その手順に従って提案を書く。
既存提案（特に rejected の理由）の読み込み、提案ファイルの形式、件数上限、
役割の境界（採否は人間・実装は improve の仕事）などの規定はすべて propose.md 側にある。
ここには書かないし、ここで上書きもしない。

## 4. 完了確認

以下は propose.md の手順に含まれるものだが、抜けやすいので終了前に揃っているか
確認する（チェック内容の詳細が食い違ったら propose.md が正）:

- `aro proposals check --repo . --strict` が通っている
- 変更を commit した（`.ai/local/proposals/` の新規ファイルのみ）
- `git fetch origin <default branch>` の後、`aro guard --repo . --base origin/<default branch>`
  が通っている
- PR タイトル規約 `docs(proposals): <提案の要約>` を開発者に提示した。
  PR の作成は開発者の確認を得てから行い、merge は常に人間が判断する
