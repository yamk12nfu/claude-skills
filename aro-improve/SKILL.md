---
name: aro-improve
description: aro (ai-repo-ops) の Proposal Loop の実装フェーズ（PR②）を起動する。.ai/managed/prompts/improve.md の手順に委譲する薄いラッパーで、前提確認と起動だけを担う。「improve して」「accepted を実装して」「採用済みの提案を実装して」「改善を実施して」「Proposal Loop の実装側を回して」と言われた時に使用する。aro が導入された（.ai/project.yaml がある）リポジトリでのみ動作する。新しい提案を書くのは aro-propose の担当、セッション終了時の気づきの走り書き収穫は knowledge-harvest の担当なので、このスキルは使わない。
---

# aro-improve — Proposal Loop の実装フェーズ起動

aro の Proposal Loop の実装フェーズ（PR②）を起動する。全体像は対象 repo に配布された
docs（ai-repo-ops の `docs/proposal-loop.md`）にある。

**手順の正本はこの skill ではなく、対象 repo の `.ai/managed/prompts/improve.md` である。**
improve.md は `aro sync` でバージョン管理され、repo ごと・時期ごとに更新される。
この skill が手順の中身を複製すると distribution 更新のたびに腐るため、
skill が持つのは起動まわりの段取りだけとする。
この skill と improve.md の記述が食い違ったら、常に improve.md に従うこと。

## 1. 前提確認

- リポジトリ直下に `.ai/project.yaml` があるか確認する。無ければ aro 未導入なので、
  その旨を伝えて終了する（`aro init` を勝手に実行しない）。
- `.ai/managed/prompts/improve.md` があるか確認する。無ければ distribution が古いので、
  `aro sync` での更新が必要と伝えて終了する。
- `aro` の起動方法を repo ごとに確認する。PATH にあるとは限らない。package.json の
  scripts / devDependencies、CLAUDE.md 等の既存設定から、その repo で使われている
  起動方法（node 絶対パスでの直接起動など）を特定する。repo のパッケージマネージャに
  従うこと（npm 管理の repo に pnpm を持ち込まない）。

## 2. 本体（improve.md へ委譲）

`.ai/managed/prompts/improve.md` を読み、その手順に従って改善を 1 件実施する。
開始前の安全確認（clean worktree・最新 default branch 起点の専用ブランチ）も
improve.md の手順に含まれているため、この skill 側では重複して規定しない。

委譲にあたり、improve.md の規定を skill 側の都合で上書きしない。特に以下は
improve.md が定める要点であり、この skill はそれに従うことを妨げない
（詳細・最新の規定は improve.md が正）:

- 実装対象は `status: accepted` の提案から 1 件選ぶことが既定
  （accepted が 1 件も無い場合のみ自選）
- stale と報告された accepted は選ばない。accepted がすべて stale なら
  自選に進まず停止し、人間に再確認を求める
- 実装可能な accepted が複数あるときは一覧を提示して開発者が選ぶ
  （提案の順位付け・選抜は AI の仕事ではない）
- 実装が自己検証を通ったら、その提案の `status` を `accepted` → `done` に変更して
  同じ PR に含める

## 3. 終了時

improve.md の出力規定に従って報告する。PR タイトル規約は
`chore(ai-improve): <改善の要約>`（improve.md の規定）。
PR の作成は開発者の確認を得てから行い、merge は常に人間が判断する。
