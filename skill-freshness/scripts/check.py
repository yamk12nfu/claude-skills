#!/usr/bin/env python3
"""スキル・プラグイン鮮度チェッカー。

~/.claude/skills のスキル、~/.agents/skills(skills.sh CLI管理)、
Claude Code プラグインについて、配布元(上流)と照合して最新かどうかを報告する。
出所は同ディレクトリの sources.json で管理する。

使い方:
    python3 check.py                # フルチェック(ネットワークアクセスあり)
    python3 check.py --offline      # ネットワークを使わず前回取得したキャッシュと照合
    python3 check.py --diff <name>  # 指定スキルのローカル→上流の差分を表示
                                    # (+行 = 上流の新規内容 = 更新で入ってくるもの)
"""

import datetime
import filecmp
import json
import os
import re
import subprocess
import sys
import urllib.request

HOME = os.path.expanduser("~")
SKILLS_DIR = os.path.join(HOME, ".claude", "skills")
AGENTS_LOCK = os.path.join(HOME, ".agents", ".skill-lock.json")
AGENTS_SKILLS_DIR = os.path.join(HOME, ".agents", "skills")
PLUGINS_DIR = os.path.join(HOME, ".claude", "plugins")
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES_FILE = os.path.join(BASE, "sources.json")
REPORT_FILE = os.path.join(BASE, "last-report.md")
CACHE = os.path.join(HOME, ".cache", "skill-freshness")
IGNORE_FILES = {".DS_Store", ".in_use"}
OFFLINE = "--offline" in sys.argv


def run(cmd, cwd=None, timeout=120):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except Exception as e:  # noqa: BLE001
        return 1, "", str(e)


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return None


def age_str(path):
    try:
        mtime = datetime.datetime.fromtimestamp(os.path.getmtime(path))
    except OSError:
        return "?", "?"
    days = (datetime.datetime.now() - mtime).days
    return mtime.strftime("%Y-%m-%d"), f"{days}日"


def last_verified(skill_dir):
    """SKILL.md frontmatter の last-verified: YYYY-MM-DD を返す(なければNone)。"""
    try:
        with open(os.path.join(skill_dir, "SKILL.md"), encoding="utf-8") as f:
            head = f.read(2000)
    except OSError:
        return None
    m = re.search(r"^last-verified:\s*(\d{4}-\d{2}-\d{2})", head, re.M)
    return m.group(1) if m else None


def strip_frontmatter(text):
    if text.startswith("---"):
        parts = text.split("\n---", 2)
        if len(parts) >= 2:
            return parts[1].split("\n", 1)[-1] if len(parts) == 2 else parts[2]
    return text


def normalize(text):
    return "\n".join(line.rstrip() for line in strip_frontmatter(text).strip().splitlines())


def ensure_repo(repo):
    """上流リポジトリのshallowクローンをキャッシュし、最新化してパスを返す。"""
    dest = os.path.join(CACHE, repo.replace("/", "__"))
    if not os.path.isdir(os.path.join(dest, ".git")):
        if OFFLINE:
            return None, "キャッシュなし(--offline)"
        os.makedirs(CACHE, exist_ok=True)
        rc, _, err = run(
            ["git", "clone", "--depth", "1", "--quiet", f"https://github.com/{repo}.git", dest],
            timeout=300,
        )
        if rc != 0:
            return None, f"clone失敗: {err[:80]}"
    elif not OFFLINE:
        run(["git", "fetch", "--depth", "1", "--quiet", "origin"], cwd=dest, timeout=300)
        run(["git", "reset", "--hard", "--quiet", "origin/HEAD"], cwd=dest)
    return dest, None


def fetch_raw(repo, path):
    if OFFLINE:
        return None
    url = f"https://raw.githubusercontent.com/{repo}/HEAD/{path}"
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return r.read().decode("utf-8", "replace")
    except Exception:  # noqa: BLE001
        return None


def list_files(root):
    out = set()
    for cur, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d != ".git" and d not in IGNORE_FILES]
        for f in files:
            if f in IGNORE_FILES:
                continue
            out.add(os.path.relpath(os.path.join(cur, f), root))
    return out


def dir_diff(upstream, local):
    """上流ディレクトリとローカルの内容差分をリストで返す(空なら一致)。"""
    a, b = list_files(upstream), list_files(local)
    diffs = [f"上流のみ: {f}" for f in sorted(a - b)]
    diffs += [f"ローカルのみ: {f}" for f in sorted(b - a)]
    for f in sorted(a & b):
        try:
            if not filecmp.cmp(os.path.join(upstream, f), os.path.join(local, f), shallow=False):
                diffs.append(f"変更: {f}")
        except OSError:
            diffs.append(f"比較不可: {f}")
    return diffs


def check_plugins(report):
    installed = load_json(os.path.join(PLUGINS_DIR, "installed_plugins.json")) or {}
    markets = load_json(os.path.join(PLUGINS_DIR, "known_marketplaces.json")) or {}
    latest = {}
    for mname, m in markets.items():
        loc = m.get("installLocation")
        if not loc or not os.path.isdir(loc):
            continue
        data = None
        if os.path.isdir(os.path.join(loc, ".git")):
            # git クローン型: fetch して上流の marketplace.json を読む
            if not OFFLINE:
                run(["git", "fetch", "--quiet", "origin"], cwd=loc, timeout=120)
            rc, ref, _ = run(["git", "rev-parse", "--abbrev-ref", "origin/HEAD"], cwd=loc)
            if rc != 0:
                ref = "origin/main"
            rc, content, _ = run(["git", "show", f"{ref}:.claude-plugin/marketplace.json"], cwd=loc)
            if rc == 0:
                try:
                    data = json.loads(content)
                except ValueError:
                    data = None
        else:
            # スナップショット型: GitHub から最新の marketplace.json を直接取得
            repo = (m.get("source") or {}).get("repo")
            if repo:
                content = fetch_raw(repo, ".claude-plugin/marketplace.json")
                if content:
                    try:
                        data = json.loads(content)
                    except ValueError:
                        data = None
        if data is None:
            # 取得失敗時はローカルスナップショット(CLIが定期更新)にフォールバック
            data = load_json(os.path.join(loc, ".claude-plugin", "marketplace.json"))
        if data:
            latest[mname] = {}
            for p in data.get("plugins", []):
                latest[mname][p.get("name")] = {
                    "version": p.get("version"),
                    "source": p.get("source"),
                    "location": loc,
                }
    report.append("## 1. プラグイン(marketplace管理)")
    report.append("")
    report.append("| プラグイン | インストール版 | 上流最新 | 状態 |")
    report.append("|---|---|---|---|")
    for key, entries in (installed.get("plugins") or {}).items():
        name, _, mkt = key.partition("@")
        inst = entries[0].get("version", "?") if entries else "?"
        install_path = entries[0].get("installPath", "") if entries else ""
        up = latest.get(mkt, {}).get(name)
        up_ver = up.get("version") if up else None
        if up is None:
            status = "❓ 上流情報を取得できず"
            up_disp = "?"
        elif up_ver and up_ver == inst:
            status = "✅ 最新"
            up_disp = up_ver
        elif up_ver and inst not in ("unknown", "?"):
            status = f"⬆️ 更新あり → `claude plugin update {key}`"
            up_disp = up_ver
        else:
            # バージョン表記がない場合はディレクトリ内容で比較する
            up_disp = up_ver or "表記なし"
            src = up.get("source")
            if isinstance(src, dict):
                src = src.get("path") or src.get("source")
            src_dir = None
            if isinstance(src, str) and src.startswith("./"):
                src_dir = os.path.join(up["location"], src[2:])
            if src_dir and os.path.isdir(src_dir) and os.path.isdir(install_path):
                diffs = dir_diff(src_dir, install_path)
                status = ("✅ 内容一致(最新)" if not diffs
                          else f"⬆️ 内容差分 {len(diffs)}件 → `claude plugin update {key}`"
                               "(版数据え置き更新だとCLIが最新扱いすることあり。その場合は次の版上げ待ち)")
            else:
                status = "❓ バージョン表記なし・内容比較も不可"
        report.append(f"| {name}@{mkt} | {inst} | {up_disp} | {status} |")
    report.append("")


def check_skills(report):
    sources = (load_json(SOURCES_FILE) or {}).get("skills", {})
    tracked, local_made, unknown = [], [], []

    names = sorted(
        n for n in os.listdir(SKILLS_DIR)
        if os.path.isdir(os.path.join(SKILLS_DIR, n)) and not n.startswith(".")
        and n != "skill-freshness"
    )
    for name in names:
        local_dir = os.path.join(SKILLS_DIR, name)
        src = sources.get(name)
        mdate, mage = age_str(local_dir)
        if src is None:
            unknown.append((name, mdate, mage, "**sources.json 未登録**"))
        elif src["type"] == "github-dir":
            repo_dir, err = ensure_repo(src["repo"])
            if repo_dir is None:
                tracked.append((name, src["repo"], f"⚠️ {err}"))
                continue
            upstream = os.path.join(repo_dir, src["path"])
            if not os.path.isdir(upstream):
                tracked.append((name, src["repo"], "⚠️ 上流にパスが見つからない(移動/削除?)"))
                continue
            diffs = dir_diff(upstream, local_dir)
            if not diffs:
                tracked.append((name, src["repo"], "✅ 上流と一致(最新)"))
            else:
                detail = "、".join(diffs[:4]) + ("…" if len(diffs) > 4 else "")
                tracked.append((name, src["repo"], f"⬆️ 差分 {len(diffs)}件({detail})"))
        elif src["type"] == "github-file":
            remote = fetch_raw(src["repo"], src["path"])
            local_md = os.path.join(local_dir, "SKILL.md")
            if remote is None:
                tracked.append((name, src["repo"], "⚠️ 上流ファイル取得失敗"))
            elif not os.path.isfile(local_md):
                tracked.append((name, src["repo"], "⚠️ ローカルにSKILL.mdなし"))
            else:
                with open(local_md, encoding="utf-8") as f:
                    local_text = f.read()
                if normalize(remote) == normalize(local_text):
                    tracked.append((name, src["repo"], "✅ SKILL.md本文一致(最新)"))
                else:
                    tracked.append((name, src["repo"], "⬆️ SKILL.md本文に差分あり"))
        elif src["type"] == "local":
            lv = last_verified(local_dir)
            if lv:
                days = (datetime.date.today() - datetime.date.fromisoformat(lv)).days
                local_made.append((name, f"{lv}(点検)", f"{days}日", src.get("note", "")))
            else:
                local_made.append((name, mdate, mage, src.get("note", "")))
        else:
            unknown.append((name, mdate, mage, src.get("candidate", "")))

    # skills.sh CLI 管理分(~/.agents/skills)はロックファイルから自動チェック
    lock = load_json(AGENTS_LOCK) or {}
    for name, meta in (lock.get("skills") or {}).items():
        repo = meta.get("source")
        path = meta.get("skillPath")
        local_md = os.path.join(AGENTS_SKILLS_DIR, name, "SKILL.md")
        if not (repo and path and os.path.isfile(local_md)):
            continue
        remote = fetch_raw(repo, path)
        if remote is None:
            tracked.append((f"{name} (~/.agents)", repo, "⚠️ 上流ファイル取得失敗"))
        else:
            with open(local_md, encoding="utf-8") as f:
                local_text = f.read()
            if normalize(remote) == normalize(local_text):
                tracked.append((f"{name} (~/.agents)", repo, "✅ SKILL.md本文一致(最新)"))
            else:
                tracked.append((f"{name} (~/.agents)", repo, "⬆️ SKILL.md本文に差分あり"))

    report.append("## 2. 上流追跡スキル(配布元と照合)")
    report.append("")
    report.append("| スキル | 出所 | 状態 |")
    report.append("|---|---|---|")
    for row in tracked:
        report.append("| " + " | ".join(row) + " |")
    report.append("")
    report.append("> 「差分あり」は上流の更新とローカル改変のどちらもありうる。上書き前に必ず diff を確認すること。")
    report.append("")

    report.append("## 3. 自作スキル(上流なし・経過日数のみ)")
    report.append("")
    report.append("| スキル | 最終更新 | 経過 | メモ |")
    report.append("|---|---|---|---|")
    for row in local_made:
        report.append("| " + " | ".join(row) + " |")
    report.append("")

    if unknown:
        report.append("## 4. 出所不明・未登録")
        report.append("")
        report.append("| スキル | 最終更新 | 経過 | 出所候補 |")
        report.append("|---|---|---|---|")
        for row in unknown:
            report.append("| " + " | ".join(row) + " |")
        report.append("")
        report.append("> 出所が判明したら sources.json に追記すると以後チェック対象になる。")
        report.append("")


def show_diff(name):
    """ローカル→上流の差分を表示する。+行が上流の新規内容(更新で入ってくるもの)。"""
    sources = (load_json(SOURCES_FILE) or {}).get("skills", {})
    src = sources.get(name)
    base_dir = SKILLS_DIR
    if src is None:
        meta = ((load_json(AGENTS_LOCK) or {}).get("skills") or {}).get(name)
        if meta:
            src = {"type": "github-file", "repo": meta["source"], "path": meta["skillPath"]}
            base_dir = AGENTS_SKILLS_DIR
    if src is None:
        print(f"{name}: sources.json に未登録のため diff を表示できない")
        return 1
    t = src.get("type")
    if t == "github-dir":
        repo_dir, err = ensure_repo(src["repo"])
        if repo_dir is None:
            print(f"上流取得失敗: {err}")
            return 1
        upstream = os.path.join(repo_dir, src["path"])
        local = os.path.join(base_dir, name)
        _, out, _ = run(["diff", "-ru", "--exclude=.git", "--exclude=.DS_Store", local, upstream], timeout=60)
        print(out if out else "(差分なし)")
    elif t == "github-file":
        remote = fetch_raw(src["repo"], src["path"])
        if remote is None:
            print("上流ファイル取得失敗")
            return 1
        local_md = os.path.join(base_dir, name, "SKILL.md")
        try:
            with open(local_md, encoding="utf-8") as f:
                local_text = f.read()
        except OSError:
            print(f"ローカルにSKILL.mdなし: {local_md}")
            return 1
        import difflib
        out = "\n".join(difflib.unified_diff(
            normalize(local_text).splitlines(), normalize(remote).splitlines(),
            fromfile=f"ローカル {name}/SKILL.md (frontmatter除去)",
            tofile=f"上流 {src['repo']}/{src['path']} (frontmatter除去)", lineterm=""))
        print(out if out else "(本文差分なし)")
    else:
        print(f"{name}: type={t}(上流なし)のため diff 対象外")
    return 0


def main():
    if "--diff" in sys.argv:
        i = sys.argv.index("--diff")
        if i + 1 >= len(sys.argv):
            print("使い方: check.py --diff <skill-name>")
            sys.exit(2)
        sys.exit(show_diff(sys.argv[i + 1]))
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    mode = "オフライン(キャッシュ照合)" if OFFLINE else "オンライン(上流照合)"
    report = [f"# スキル鮮度レポート", "", f"生成: {now} / モード: {mode}", ""]
    check_plugins(report)
    check_skills(report)
    report.append("## 更新のしかた")
    report.append("")
    report.append("- プラグイン: `claude plugin update <name>@<marketplace>`")
    report.append("- github-dir スキル: `diff -ru ~/.claude/skills/<name> ~/.cache/skill-freshness/<owner>__<repo>/<path>` で差分確認後、"
                  "`rsync -a --delete <キャッシュ側パス>/ ~/.claude/skills/<name>/` で上書き")
    report.append("- 自作スキル: 内容を見直したら `touch` するか frontmatter に `last-verified:` を記録")
    text = "\n".join(report) + "\n"
    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write(text)
    print(text)
    print(f"(レポート保存先: {REPORT_FILE})")


if __name__ == "__main__":
    main()
