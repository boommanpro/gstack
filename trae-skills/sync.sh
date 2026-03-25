#!/usr/bin/env bash
# gstack Trae sync — Synchronize Trae skills with upstream gstack changes
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GSTACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TRAE_SKILLS_DIR="$SCRIPT_DIR"

info "Syncing Trae skills from gstack..."

check_changes() {
  local has_changes=0
  
  for tmpl in "$GSTACK_ROOT"/*/SKILL.md.tmpl; do
    if [ -f "$tmpl" ]; then
      local skill_name="$(basename "$(dirname "$tmpl")")"
      local trae_skill="$TRAE_SKILLS_DIR/gstack-$skill_name/SKILL.md"
      
      if [ ! -f "$trae_skill" ] || [ "$tmpl" -nt "$trae_skill" ]; then
        has_changes=1
        break
      fi
    fi
  done
  
  if [ -f "$GSTACK_ROOT/SKILL.md.tmpl" ]; then
    if [ ! -f "$TRAE_SKILLS_DIR/gstack/SKILL.md" ] || [ "$GSTACK_ROOT/SKILL.md.tmpl" -nt "$TRAE_SKILLS_DIR/gstack/SKILL.md" ]; then
      has_changes=1
    fi
  fi
  
  return $has_changes
}

regenerate_docs() {
  info "Regenerating Trae skill documentation..."
  (
    cd "$GSTACK_ROOT"
    bun run gen:skill-docs --host trae
  )
}

sync_skills() {
  info "Syncing skill files..."
  
  local trae_gstack="$TRAE_SKILLS_DIR/gstack"
  mkdir -p "$trae_gstack"
  
  if [ -f "$GSTACK_ROOT/SKILL.md" ]; then
    sed -e "s|~/.claude/skills/gstack|$trae_gstack|g" \
        -e "s|\.claude/skills/gstack|$trae_gstack|g" \
        -e "s|\$GSTACK_ROOT|$trae_gstack|g" \
        -e "s|\$GSTACK_BIN|$trae_gstack/bin|g" \
        -e "s|\$GSTACK_BROWSE|$trae_gstack/browse/dist|g" \
        "$GSTACK_ROOT/SKILL.md" > "$trae_gstack/SKILL.md"
    success "Synced root skill"
  fi
  
  local sync_count=0
  for skill_dir in "$GSTACK_ROOT"/*/; do
    if [ -f "$skill_dir/SKILL.md.tmpl" ]; then
      local skill_name="$(basename "$skill_dir")"
      
      [ "$skill_name" = "node_modules" ] && continue
      [ "$skill_name" = "trae-skills" ] && continue
      [ "$skill_name" = ".agents" ] && continue
      [ "$skill_name" = ".github" ] && continue
      
      local trae_skill="$TRAE_SKILLS_DIR/gstack-$skill_name"
      mkdir -p "$trae_skill"
      
      if [ -f "$skill_dir/SKILL.md" ]; then
        sed -e "s|~/.claude/skills/gstack|$trae_gstack|g" \
            -e "s|\.claude/skills/gstack|$trae_gstack|g" \
            -e "s|\$GSTACK_ROOT|$trae_gstack|g" \
            -e "s|\$GSTACK_BIN|$trae_gstack/bin|g" \
            -e "s|\$GSTACK_BROWSE|$trae_gstack/browse/dist|g" \
            "$skill_dir/SKILL.md" > "$trae_skill/SKILL.md"
        ((sync_count++))
      fi
    fi
  done
  
  success "Synced $sync_count skills"
}

rebuild_browse() {
  local browse_bin="$GSTACK_ROOT/browse/dist/browse"
  
  if [ ! -x "$browse_bin" ]; then
    info "Rebuilding browse binary..."
    (
      cd "$GSTACK_ROOT"
      bun run build
    )
    success "Browse binary rebuilt"
  fi
}

main() {
  if check_changes; then
    info "No changes detected - skills are up to date"
  else
    warn "Changes detected - syncing..."
    regenerate_docs
    sync_skills
    rebuild_browse
    success "Sync complete!"
  fi
}

FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f) FORCE=1; shift ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Synchronize Trae skills with upstream gstack changes."
      echo ""
      echo "Options:"
      echo "  --force, -f    Force sync even if no changes detected"
      echo "  --help, -h     Show this help message"
      echo ""
      exit 0
      ;;
    *) shift ;;
  esac
done

if [ $FORCE -eq 1 ]; then
  warn "Force sync requested"
  regenerate_docs
  sync_skills
  rebuild_browse
  success "Force sync complete!"
else
  main
fi
