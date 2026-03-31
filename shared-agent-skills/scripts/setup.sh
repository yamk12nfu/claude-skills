#!/usr/bin/env bash
# shared-agent-skills: Setup script
# .agent/skills/ に実体を配置し、各エージェントのディレクトリからシンボリックリンクを張る
#
# Usage:
#   bash scripts/setup.sh [project-root]
#
# Options:
#   --with-agents-md   AGENTS.md を作成し CLAUDE.md をシンボリックリンクにする
#   --migrate          既存の .claude/skills/ や .codex/skills/ の実体を .agent/skills/ へ移動
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

# --- 1. Create .agent/skills/ directory ---
echo ""
echo "=== Step 1: .agent/skills/ ディレクトリを作成 ==="
if [ -d ".agent/skills" ]; then
  echo "  Already exists: .agent/skills/"
else
  run_cmd mkdir -p .agent/skills
  echo "  Created: .agent/skills/"
fi

# --- 2. Migrate existing skills if requested ---
if [ "$MIGRATE" = true ]; then
  echo ""
  echo "=== Step 2: 既存スキルを .agent/skills/ へ移動 ==="
  for agent_dir in .claude .codex; do
    skills_dir="$agent_dir/skills"
    if [ -d "$skills_dir" ] && [ ! -L "$skills_dir" ]; then
      echo "  Migrating $skills_dir/ ..."
      for item in "$skills_dir"/*/; do
        if [ -d "$item" ]; then
          skill_name=$(basename "$item")
          if [ -d ".agent/skills/$skill_name" ]; then
            echo "    Skip (already exists): $skill_name"
          else
            run_cmd mv "$item" ".agent/skills/$skill_name"
            echo "    Moved: $skill_name"
          fi
        fi
      done
      # Remove the original directory (now empty or with only files)
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

# --- 3. Create symlinks ---
echo ""
echo "=== Step 3: シンボリックリンクを作成 ==="

AGENT_DIRS=(".claude" ".codex")

for agent_dir in "${AGENT_DIRS[@]}"; do
  skills_path="$agent_dir/skills"

  # Create parent directory if needed
  if [ ! -d "$agent_dir" ]; then
    run_cmd mkdir -p "$agent_dir"
    echo "  Created: $agent_dir/"
  fi

  if [ -L "$skills_path" ]; then
    current_target=$(readlink "$skills_path")
    echo "  Already symlinked: $skills_path -> $current_target"
  elif [ -d "$skills_path" ]; then
    echo "  WARNING: $skills_path is a real directory. Use --migrate to move contents first."
  else
    run_cmd ln -s ../.agent/skills "$skills_path"
    echo "  Symlinked: $skills_path -> ../.agent/skills"
  fi
done

# --- 4. AGENTS.md / CLAUDE.md setup ---
if [ "$WITH_AGENTS_MD" = true ]; then
  echo ""
  echo "=== Step 4: AGENTS.md / CLAUDE.md をセットアップ ==="

  if [ -f "AGENTS.md" ] && [ ! -L "AGENTS.md" ]; then
    echo "  AGENTS.md already exists (real file)."
  elif [ -f "CLAUDE.md" ] && [ ! -L "CLAUDE.md" ] && [ ! -f "AGENTS.md" ]; then
    # CLAUDE.md exists but AGENTS.md doesn't -> rename CLAUDE.md to AGENTS.md
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
| (run `ls .agent/skills/` to list) | |

AGENTSEOF
    fi
    echo "  Created: AGENTS.md"
  fi

  # Create CLAUDE.md symlink
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
echo "  .agent/skills/          <- Skill の実体を配置"
echo "  .claude/skills           -> ../.agent/skills (symlink)"
echo "  .codex/skills            -> ../.agent/skills (symlink)"
if [ "$WITH_AGENTS_MD" = true ]; then
  echo "  AGENTS.md               <- ガイドラインの実体"
  echo "  CLAUDE.md                -> AGENTS.md (symlink)"
fi
echo ""
echo "Next steps:"
echo "  1. .agent/skills/ にスキルを追加 (各スキルは SKILL.md を含むディレクトリ)"
echo "  2. git add .agent/ .claude/skills .codex/skills && git commit"
