# pstack for Claude Code + Codex

Cursor の [pstack](https://github.com/cursor/plugins/tree/main/pstack)（poteto 作、v0.15.5、MIT）を Claude Code に移植したもの。
司令塔は Claude Code。各スキルのサブエージェント（パネルの席）は、役割ごとに **Claude サブエージェント** か **Codex CLI（`codex exec`）** に振り分けて実行する。
Cursor 版で Grok が担当していた席は Claude と Codex で置き換えた。

## インストール

```bash
bash ~/claude-skills/pstack/scripts/install.sh   # ~/.claude/skills/pstack -> このディレクトリ
```

Claude Code はこれを skills-dir プラグイン `pstack@skills-dir` として読み込む。確認には `claude plugin details pstack` を使う。
新しいセッションで `/setup-pstack` を実行し、役割ごとのモデルを決める。実行しなければ同梱の既定値で動く。

todo list（Claude Code のタスクリスト。入力欄の上に出て、Ctrl+T で開閉する）を出すには、`~/.claude/settings.json` の `env` に次の 2 行を入れる。セッション起動時にしか読まれないので、Orca などどの経路で起動しても効くよう、全体設定にしている。

```json
"CLAUDE_CODE_ENABLE_TODO_TOOLS": "1",
"CLAUDE_CODE_TODO_REMINDER_MODE": "off"
```

1 行目でタスクツールを有効にする。2 行目は Claude Code 本体の「タスクツールを使え」という定期的な促しを止め、pstack 以外の会話でタスク一覧が出にくいようにする。設定を変えたくない環境では、`claude-pstack`（`install.sh` が `~/.local/bin` にリンクする）で起動すれば、そのセッションだけ有効になる。

使い方は Cursor 版と同じ。

```
/poteto-mode スクロールが idle 中も 750ms ごとにずれるバグ。まず再現して、修正して検証して
/how 実行のキャンセルはどう動いている？
/interrogate この PR をレビューして
```

## 3 段構え

1. **入口**。人がスラッシュコマンドで呼ぶ。全スキルに `disable-model-invocation: true` が付いており、モデルが勝手に起動することはない。
2. **司令塔**。`/poteto-mode` がタスクを playbook（23 本）に当てはめ、その手順を todo にコピーして進める。一度入ると sticky になる（後述）。
3. **専門スキル**。playbook の各ステップが `how` / `why` / `architect` / `arena` / `interrogate` / `swarm` / `reflect` などを名指しで呼ぶ。各スキルは自分の役割行を `~/.claude/rules/pstack-models.md` から読み、席の数と担当モデルを決める。

仕上げは `unslop` / `technical-writing` / `no-comments` / `deslop` / `tdd`、土台は `principle-*`（23 本）。

## todo list

Claude Code は新しいモデル（Opus 5.5、Fable など）ではタスクツール（TaskCreate / TaskUpdate）を既定で無効にしている。有効にする環境変数 `CLAUDE_CODE_ENABLE_TODO_TOOLS` は起動時にしか読まれず、プラグインやスキルからは設定できない。そのため上記の全体設定で有効にする。

- `references/todo.md` がルールの正本。`scripts/pstack-playbook <name>` が playbook の番号付き手順を `<n>. <見出し>` の形で出力し、セッションの playbook として記録する。モデルはその各行を、そのまま 1 行 1 タスクで `TaskCreate` する。skip する手順も `skip: <理由>` として作り、すぐ完了にする。手順を始めたら `in_progress`、検証が通ったら `completed` にする。
- 「Run Opening a PR」の手順は、`<n>a. /deslop`、`<n>b. /no-comments`、`<n>. Run Opening a PR` の 3 タスクに分けて出す。PR 作成を 1 タスクで完了にして、中の 2 つを飛ばす抜けが実際に起きたため。それぞれ実行するか `skip: <理由>` を残すまで、フックは欠けとして扱う。
- フックで強制する（`scripts/sticky-reminder`）。
  - `gate`（PreToolUse）。poteto-mode 中は、本体スレッドの Edit / Write を次のあいだ拒否する。todo が無い。記録した playbook の手順番号に欠けがある（完了か `<n>. skip: <理由>` が必要）。`in_progress` のタスクが 1 つも無い。サブエージェントの編集は、親が進行中にしている手順の中の作業として通す。
  - `stop`（Stop）。手順が欠けているとき、または未完了のタスクを残してターンを終えようとしたとき、1 回だけ差し戻す。
  - 毎ターンの注意書き（UserPromptSubmit）に、playbook 名と未完了タスクの一覧を載せる。Cursor の todo パネルが常に見えている状態の代わり。
- 狙いは Cursor と同じで、手順を飛ばすこと自体は禁止しない。飛ばすなら `skip: <理由>` として必ずリストに残す。リポジトリ独自の `/self-review` などは、interrogate / no-comments / deslop の代わりにならない。
- タスクツールが無いセッションでは、`sticky-reminder on` が設定方法を表示する。モデルはそれをユーザーに 1 行で伝え、markdown のチェックリストファイルで代用する。

## モデル振り分けの仕組み

| 部品 | 役割 |
|---|---|
| `~/.claude/rules/pstack-models.md` | 役割 → モデルの対応表。`/setup-pstack` が書く。Claude Code が毎セッション自動で読み込む |
| `templates/pstack-models.md` | 既定の対応表と値の書式 |
| `scripts/pstack-model "<role>"` | 役割を解決し、席ごとの値を 1 行ずつ出す。ユーザー設定に行が無ければ既定値を使う |
| `references/dispatch.md` | 席の起動手順。全スキル共通の正本 |
| `scripts/codex-run` | Codex 席を実行し、`result.md` と `DONE`（終了コード）を出力ディレクトリに残す |

値の書式は次の 3 種類。

- `claude:fable` / `claude:opus` / `claude:sonnet` / `claude:haiku` は、Agent ツールでそのモデルのサブエージェントを起動する。
- `codex:<model>:<effort>`（例 `codex:gpt-6.1-sol:max`）は、Bash のバックグラウンド実行で `codex exec` を起動する。read 席は read-only サンドボックス、write 席は workspace-write サンドボックスで動く。
- `inherit-parent` / `auto` は、親と同じモデルの Claude サブエージェントになる。

既定値は次のとおり。Cursor 版の構成と、元になった役割図の割り当てを踏襲している。

| 役割 | 既定 |
|---|---|
| feature, refactoring / bug-fix / perf-issue / hillclimb | `codex:gpt-6-luna:max` |
| judgment and prose / hardest tasks | `claude:fable` |
| how explorer / why investigators | `claude:opus` |
| how explainer / why synthesizer | `claude:fable` |
| reflect tooling | `codex:gpt-6-luna:max` |
| reflect judgment, divergent, synthesizer | `claude:fable` |
| arena runners / architect runners / interrogate reviewers | `claude:fable, claude:opus, codex:gpt-6-astra:max, codex:gpt-6.1-sol:max` |
| arena cross-judge pool | `claude:fable, codex:gpt-6-astra:max, codex:gpt-6.1-sol:max`（親と別系統の Codex を優先） |
| swarm workers | `codex:gpt-6-luna:max` |

## Cursor 版からの主な変更

| Cursor | この移植 |
|---|---|
| `Task` ツール + `model` スラッグ | `dispatch.md` の手順で Agent ツール（Claude）か `codex-run`（Codex）を使う |
| `readonly: true` | `pstack:pstack-reader`（読み取り専用ツールのみのエージェント）か、Codex の read-only サンドボックス |
| MCP が必要な read 席（why / reflect） | `general-purpose` に「書き込み禁止」の brief を付ける |
| `environment: "cloud"` のワーカー | ローカルのバックグラウンド席。書き込む席にはそれぞれ git worktree を割り当てる |
| `~/.cursor/rules/pstack-models.mdc` | `~/.claude/rules/pstack-models.md` |
| `agent-transcripts/` | `~/.claude/projects/<slug>/<session-id>.jsonl`（Codex 側は `~/.codex/sessions/`） |
| sticky mode（`mode: true`） | プラグインの `UserPromptSubmit` フック（`scripts/sticky-reminder`）。セッション ID のマーカーがあるあいだ、毎ターン注意書きを差し込む。同じスクリプトの `gate` を `PreToolUse` フックにして、todolist が無いあいだ Edit、Write、NotebookEdit を拒否する |
| `cursor-team-kit` の deslop / control-ui / control-cli | 同名のスキルを同梱した。control-ui は playwright-cli、Playwright MCP、terminal-browser に振り分け、control-cli は Bash と tmux で操作する |
| Cursor 組み込みの `create-skill` | `skill-creator` スキル |
| Bugbot / Origin | レビューボット全般（Bugbot、CodeRabbit、Codex review など）。Origin は削除し、`gh` のみにした |
| `make-bot-ui`、benny automation、docs/guide | Cursor（Grok Bot、Cursor automations）専用なので移植していない |

### Claude Code + Codex 特有の注意

- **入れ子の制約**。Claude Code のサブエージェントは Claude サブエージェントを起動できない。サブエージェントの中では、Codex 席は `codex-run` で起動し、Claude 席は自分でインラインに実行する（`dispatch.md` 5 節）。
- **Codex からの見え方**。`~/.claude/skills` は `~/.agents/skills` へのリンクなので、Codex もこのディレクトリを走査する。各スキルに `agents/openai.yaml`（`allow_implicit_invocation: false`）を置き、Codex が暗黙に起動しないようにした。Codex 席が `interrogate` などを勝手に呼んでパネルを入れ子にする事故を防ぐため。
- **Codex 席は自己完結**。Codex は pstack も会話の文脈も知らない。brief には読むべきファイルの絶対パスと検証コマンドを書く。
- **Codex の書き込み席はファイル編集だけ**。workspace-write サンドボックスでは `.git` が読み取り専用になり、ネットワークも遮断される。commit、push、`gh` は親か Claude 席が行う。PR のオーナーや検証者は Claude 席にする。
- **完了判定**。Agent ツールの完了通知か、バックグラウンド Bash の終了と `DONE` ファイルだけで判断する。ブロックして待つ必要があるとき（`claude -p` のように通知が来ない場合など）は `scripts/codex-wait` を使う。
- **watch-pr / orch スクリプト**は bun 前提の TypeScript。実行方法は `skills/poteto-mode/playbooks/` 側に記載した。

## 動作確認済みのこと

- **E2E todo**: `claude-pstack` と opus 親で `/poteto-mode` のバグ修正を実行した。bug-fix playbook の 6 手順がそのままの文言でタスクになり、各手順が `in_progress` から `completed` に進んだ。skip した手順も完了扱いになった。`bash scripts/sticky-reminder-test` は 28 件すべて通る。
- **E2E feature playbook**: opus 親で `/poteto-mode` に median 追加を依頼した。全 8 手順がタスクになり、飛ばした 4 手順は理由付きの `skip:` として残った。throughput checkpoint の 4 項目も作られた。実装は Codex の `feature, refactoring` 席に委譲され、deslop、node での検証 9 件、コミットまで完了した。

- `pstack-model`: 既定値の解決、ユーザー設定による上書き、`feature` → `feature, refactoring` の部分一致、未知の役割はエラー。
- `codex-run`: `gpt-6-luna` の read-only 実行が成功し、`DONE=0` と回答が出力された。存在しないモデルでは `DONE=1` になり、エラー内容が `stderr.log` に残った。
- `sticky-reminder`: マーカーがあるときだけ注意書きを出す。`gate` は todolist（`todo-path` のファイルに `- [ ]` 行があるか、TodoWrite か TaskCreate を使ったこと）が無いあいだ編集を拒否する。`bash scripts/sticky-reminder-test` で確認する。
- `codex-wait`: 正常終了、失敗、タイムアウトの 3 パターンで期待どおりの終了コードを返す。
- **E2E `/interrogate`**: 新規の `claude -p` セッションで、Claude 席（sonnet）と Codex 席（gpt-6-luna）の 2 席パネルを起動した。両席とも、仕込んだ off-by-one を独立に検出した。Act On、Consider、Agreement Map まで出力された（約 $0.25）。
- **E2E `/poteto-mode`**: sticky マーカーの作成、Investigation playbook の選択、実測を根拠にした回答まで確認した。2 ターン目の `--resume` では、フックの注意書きがトランスクリプトに注入されていた。
- `claude plugin details pstack`: スキル、エージェント 3 つ、フック 1 つが認識された。
- Codex からは `allow_implicit_invocation: false` を付けた後、pstack スキルが見えなくなった。
