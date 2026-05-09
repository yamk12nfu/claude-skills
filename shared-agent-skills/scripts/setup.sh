#!/usr/bin/env bash
# shared-agent-skills: Setup script
# .agents/skills/ に実体を配置し、.claude/skills からシンボリックリンクで参照する
#
# Usage:
#   bash scripts/setup.sh [project-root]
#
# Options:
#   --with-agents-md   AGENTS.md を作成し CLAUDE.md をシンボリックリンクにする
#   --migrate          既存の .claude/skills/ の実体を .agents/skills/ へ移動
#   --dry-run          実際には変更せず、何が行われるかを表示

set -euo pipefail

# --- Parse arguments ---
PROJECT_ROOT=""
WITH_AGENTS_MD=false
MIGRATE=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --with-agents-md) WITH_AGENTS_MD=true ;;
    --migrate)        MIGRATE=true ;;
    --dry-run)        DRY_RUN=true ;;
    -*)               echo "Unknown option: $arg"; exit 1 ;;
    *)                PROJECT_ROOT="$arg" ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

cd "$PROJECT_ROOT"
echo "Project root: $PROJECT_ROOT"

# --- Helper functions ---
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# --- 1. Create .agents/skills/ directory ---
echo ""
echo "=== Step 1: .agents/skills/ ディレクトリを作成 ==="
if [ -d ".agents/skills" ]; then
  echo "  Already exists: .agents/skills/"
else
  run_cmd mkdir -p .agents/skills
  echo "  Created: .agents/skills/"
fi

# --- 2. Migrate existing skills if requested ---
if [ "$MIGRATE" = true ]; then
  echo ""
  echo "=== Step 2: 既存スキルを .agents/skills/ へ移動 ==="
  for skills_dir in .claude/skills .codex/skills; do
    if [ -d "$skills_dir" ] && [ ! -L "$skills_dir" ]; then
      echo "  Migrating $skills_dir/ ..."
      for item in "$skills_dir"/*/; do
        if [ -d "$item" ]; then
          skill_name=$(basename "$item")
          if [ -d ".agents/skills/$skill_name" ]; then
            echo "    Skip (already exists): $skill_name"
          else
            run_cmd mv "$item" ".agents/skills/$skill_name"
            echo "    Moved: $skill_name"
          fi
        fi
      done
      if [ "$DRY_RUN" = false ]; then
        rm -rf "$skills_dir"
        echo "  Removed: $skills_dir/"
      fi
    elif [ -L "$skills_dir" ]; then
      echo "  Skip (already symlink): $skills_dir"
    else
      echo "  Skip (not found): $skills_dir"
    fi
  done
else
  echo ""
  echo "=== Step 2: マイグレーションをスキップ (--migrate で有効化) ==="
fi

# --- 3. Create .claude/skills symlink ---
echo ""
echo "=== Step 3: .claude/skills シンボリックリンクを作成 ==="

if [ ! -d ".claude" ]; then
  run_cmd mkdir -p .claude
  echo "  Created: .claude/"
fi

skills_path=".claude/skills"
if [ -L "$skills_path" ]; then
  current_target=$(readlink "$skills_path")
  echo "  Already symlinked: $skills_path -> $current_target"
elif [ -d "$skills_path" ]; then
  echo "  WARNING: $skills_path is a real directory. Use --migrate to move contents first."
else
  run_cmd ln -s ../.agents/skills "$skills_path"
  echo "  Symlinked: $skills_path -> ../.agents/skills"
fi

# --- 4. AGENTS.md / CLAUDE.md setup ---
if [ "$WITH_AGENTS_MD" = true ]; then
  echo ""
  echo "=== Step 4: AGENTS.md / CLAUDE.md をセットアップ ==="

  if [ -f "AGENTS.md" ] && [ ! -L "AGENTS.md" ]; then
    echo "  AGENTS.md already exists (real file)."
  elif [ -f "CLAUDE.md" ] && [ ! -L "CLAUDE.md" ] && [ ! -f "AGENTS.md" ]; then
    run_cmd mv CLAUDE.md AGENTS.md
    echo "  Renamed: CLAUDE.md -> AGENTS.md"
  elif [ ! -f "AGENTS.md" ]; then
    echo "  AGENTS.md not found. Creating a minimal one..."
    if [ "$DRY_RUN" = false ]; then
      cat > AGENTS.md << 'AGENTSEOF'
# Project Guidelines

## Available Skills

| Skill | Description |
|-------|-------------|
| (run `ls .agents/skills/` to list) | |

AGENTSEOF
    fi
    echo "  Created: AGENTS.md"
  fi

  if [ -L "CLAUDE.md" ]; then
    echo "  CLAUDE.md is already a symlink."
  elif [ -f "CLAUDE.md" ] && [ -f "AGENTS.md" ]; then
    echo "  WARNING: Both CLAUDE.md and AGENTS.md exist as real files."
    echo "  Manually merge them, then: rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
  else
    if [ ! -L "CLAUDE.md" ]; then
      run_cmd ln -s AGENTS.md CLAUDE.md
      echo "  Symlinked: CLAUDE.md -> AGENTS.md"
    fi
  fi
fi

# --- 5. .gitignore check ---
echo ""
echo "=== Final: .gitignore の確認 ==="
echo "  Symlinks are committed to git as-is. No .gitignore changes needed."

# --- Summary ---
echo ""
echo "=== Done! ==="
echo ""
echo "Structure:"
echo "  .agents/skills/          <- Skill の実体を配置 (Codex はここを直接読む)"
echo "  .claude/skills           -> ../.agents/skills (symlink for Claude Code)"
if [ "$WITH_AGENTS_MD" = true ]; then
  echo "  AGENTS.md               <- ガイドラインの実体"
  echo "  CLAUDE.md                -> AGENTS.md (symlink)"
fi
echo ""
echo "Next steps:"
echo "  1. .agents/skills/ にスキルを追加 (各スキルは SKILL.md を含むディレクトリ)"
echo "  2. git add .agents/ .claude/skills && git commit"
