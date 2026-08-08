---
name: knowledge-harvest
description: セッション終了時に、そのセッションで得たリポジトリ固有の非自明な気づきを aro (ai-repo-ops) の proposal として .ai/local/proposals/ に収穫する。「/knowledge-harvest」「ナレッジ収穫」「気づきを収穫して」「今日の気づきを proposal にして」「セッション締め」「今日はここまで」「作業を切り上げる」と言われた時、または作業セッションを終える流れになった時に必ず使用する。aro が導入された（.ai/project.yaml がある）リポジトリでのみ動作する。最大2件まで、0件も正常な結果として扱う。
---

# Knowledge Harvest — セッション終了時のナレッジ候補収穫

セッション中に得た「このリポジトリ固有の非自明な気づき」を、忘れないうちに
aro の proposal（`.ai/local/proposals/*.md`, `status: open`）として書き残す。

これは**走り書きの収穫**であって、正式な knowledge の清書ではない。
清書は後日、人間が proposal を `accepted` にした後に `knowledge-refresh.md` の手順で行う。
採否（status の変更）は常に人間の仕事であり、この skill では絶対に行わない。

## 手順

### 1. 前提確認

- リポジトリ直下に `.ai/project.yaml` があるか確認する。無ければ aro 未導入なので、
  その旨を伝えて終了する（`aro init` を勝手に実行しない）。
- `.ai/project.yaml` の `ai.allowed_paths` に `.ai/local/proposals/**` が含まれるか確認する。
  未許可なら書き込まず、「許可設定の PR が必要」と伝えて終了する。
  自分で allowed_paths を書き換えてはいけない（書き込み境界の自己拡張は aro が禁止する設計）。
- `aro` CLI の起動方法を確認する。PATH に無ければ、その repo でこれまで使われた
  launcher（node 絶対パス等）を使う。

### 2. セッションを振り返り、候補を選ぶ

次の**すべて**を満たすものだけを候補にする:

- **リポジトリ固有**: 一般的なプログラミング知識ではない
- **非自明**: コードを一読しても分からない（隠れた制約、設計の理由、ハマりどころ）
- **根拠を指せる**: Git 追跡済みのテキストファイルを source として挙げられる

除外するもの: `.env*` / `secrets/**` / `.git/**` / `.ai/**` / 未追跡ファイルを根拠にするもの、
外部情報（Issue・PR・Slack・CI ログ）しか根拠が無いもの、推測。

**0件なら「今日は収穫なし」と一言伝えて正常終了する。** 無理にひねり出さないこと。
ノルマ化すると薄い提案で備蓄庫が埋まり、人間の採否判断が追いつかなくなって仕組みごと死ぬ。
0件で終わることが、この習慣を長く続けるための正しい挙動である。

### 3. proposal を書く（最大2件）

1件1ファイルで `.ai/local/proposals/<id>.md` を作る。`<id>` は内容が分かる kebab-case
（例: `auth-token-refresh-pitfall.md`）。frontmatter は proposal schema に厳密に従う:

```markdown
---
schema_version: 1
id: auth-token-refresh-pitfall
status: open
proposed_at_commit: <git rev-parse HEAD の完全な lowercase SHA>
sources:
  - path: src/auth/service.ts
---

## 提案: どんな knowledge entry を書くべきか

（entry のタイトル案と要旨を2〜5文で。何が非自明なのか、なぜ将来の開発者・AI に
とって価値があるのかを書く。清書時に根拠を検証しやすいよう、参照箇所を具体的に。）
```

- `id` はファイル名（拡張子除く）と一致させる
- `proposed_at_commit` は現在の HEAD の完全 SHA（40桁または64桁、lowercase）
- `sources[].path` は repo root からの正確な相対 path、1件以上、glob 不可

### 4. 検証する

```bash
aro proposals check --repo .
```

FAIL したら frontmatter を修正して通す。

### 5. 報告して終わる

書いた proposal のファイル名と要旨をユーザーに提示する。commit するかはユーザーの判断。
既存 proposal の status 変更・削除・編集は一切しない（却下済み proposal と同じネタを
再提案しないよう、書く前に既存ファイルを読んでおくこと）。
