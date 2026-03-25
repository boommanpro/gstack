#!/usr/bin/env bash
# gstack Trae global install — Install skills to ~/.trae/skills and ~/.trae-cn/skills
# Supports: macOS, Linux, Windows (Git Bash / MSYS2 / WSL)
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

detect_os() {
  case "$(uname -s)" in
    Darwin*)    echo "macos" ;;
    Linux*)     echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) echo "windows" ;;
    *)          echo "unknown" ;;
  esac
}

OS=$(detect_os)
IS_WINDOWS=0
[ "$OS" = "windows" ] && IS_WINDOWS=1

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GSTACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Installation target directories
TRAE_SKILLS_DIRS=(
  "$HOME/.trae/skills"
  "$HOME/.trae-cn/skills"
)

info "Detected OS: $OS"
info "gstack root: $GSTACK_ROOT"
info "Target directories: ${TRAE_SKILLS_DIRS[*]}"

check_bun() {
  if ! command -v bun >/dev/null 2>&1; then
    warn "bun is not installed."
    info "Installing bun..."
    
    case "$OS" in
      macos|linux)
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
        ;;
      windows)
        error "On Windows, please install bun manually: powershell -c \"irm bun.sh/install.ps1 | iex\""
        ;;
    esac
    
    if ! command -v bun >/dev/null 2>&1; then
      error "Failed to install bun. Please install it manually: https://bun.sh"
    fi
  fi
  
  success "bun is installed: $(bun --version)"
}

check_git() {
  if ! command -v git >/dev/null 2>&1; then
    error "git is required but not installed. Please install git first."
  fi
  success "git is installed: $(git --version)"
}

build_browse() {
  local browse_bin="$GSTACK_ROOT/browse/dist/browse"
  local needs_build=0
  
  if [ ! -x "$browse_bin" ]; then
    needs_build=1
  elif [ -n "$(find "$GSTACK_ROOT/browse/src" -type f -newer "$browse_bin" -print -quit 2>/dev/null)" ]; then
    needs_build=1
  elif [ "$GSTACK_ROOT/package.json" -nt "$browse_bin" ]; then
    needs_build=1
  fi
  
  if [ $needs_build -eq 1 ]; then
    info "Building browse binary..."
    (
      cd "$GSTACK_ROOT"
      bun install --frozen-lockfile 2>/dev/null || bun install
      bun run build
    )
    
    if [ ! -f "$GSTACK_ROOT/browse/dist/.version" ]; then
      git -C "$GSTACK_ROOT" rev-parse HEAD > "$GSTACK_ROOT/browse/dist/.version" 2>/dev/null || true
    fi
  fi
  
  if [ ! -x "$browse_bin" ]; then
    error "Failed to build browse binary at $browse_bin"
  fi
  
  success "browse binary ready: $browse_bin"
}

install_playwright() {
  info "Checking Playwright Chromium..."
  
  local check_cmd
  if [ $IS_WINDOWS -eq 1 ]; then
    check_cmd="node -e \"const { chromium } = require('playwright'); (async () => { const b = await chromium.launch(); await b.close(); })()\" 2>/dev/null"
  else
    check_cmd="bun --eval 'import { chromium } from \"playwright\"; const browser = await chromium.launch(); await browser.close();' >/dev/null 2>&1"
  fi
  
  if ! eval "$check_cmd"; then
    info "Installing Playwright Chromium..."
    (
      cd "$GSTACK_ROOT"
      bunx playwright install chromium
    )
    
    if [ $IS_WINDOWS -eq 1 ]; then
      if ! command -v node >/dev/null 2>&1; then
        error "Node.js is required on Windows for Playwright. Install from: https://nodejs.org/"
      fi
      
      (
        cd "$GSTACK_ROOT"
        node -e "require('playwright')" 2>/dev/null || npm install --no-save playwright
      )
    fi
  fi
  
  success "Playwright Chromium is ready"
}

generate_skill_docs() {
  info "Generating Trae skill documentation..."
  (
    cd "$GSTACK_ROOT"
    bun run gen:skill-docs --host trae
  )
  success "Skill documentation generated"
}

# Install skills to a specific target directory
install_to_target() {
  local target_skills_dir="$1"
  local target_gstack="$target_skills_dir/gstack"
  
  info "Installing to: $target_skills_dir"
  
  mkdir -p "$target_skills_dir"
  
  if [ -L "$target_gstack" ]; then
    rm -f "$target_gstack"
  elif [ -d "$target_gstack" ] && [ "$target_gstack" != "$GSTACK_ROOT" ]; then
    rm -rf "$target_gstack"
  fi
  
  mkdir -p "$target_gstack" "$target_gstack/browse" "$target_gstack/bin" "$target_gstack/review"
  
  ln -snf "$GSTACK_ROOT/bin" "$target_gstack/bin" 2>/dev/null || true
  ln -snf "$GSTACK_ROOT/browse/dist" "$target_gstack/browse/dist" 2>/dev/null || true
  ln -snf "$GSTACK_ROOT/browse/bin" "$target_gstack/browse/bin" 2>/dev/null || true
  
  if [ -f "$GSTACK_ROOT/ETHOS.md" ]; then
    ln -snf "$GSTACK_ROOT/ETHOS.md" "$target_gstack/ETHOS.md"
  fi
  
  for f in checklist.md design-checklist.md greptile-triage.md TODOS-format.md; do
    if [ -f "$GSTACK_ROOT/review/$f" ]; then
      ln -snf "$GSTACK_ROOT/review/$f" "$target_gstack/review/$f"
    fi
  done
  
  if [ -f "$GSTACK_ROOT/SKILL.md" ]; then
    sed -e "s|~/.claude/skills/gstack|$target_gstack|g" \
        -e "s|\.claude/skills/gstack|$target_gstack|g" \
        -e "s|\$GSTACK_ROOT|$target_gstack|g" \
        -e "s|\$GSTACK_BIN|$target_gstack/bin|g" \
        -e "s|\$GSTACK_BROWSE|$target_gstack/browse/dist|g" \
        "$GSTACK_ROOT/SKILL.md" > "$target_gstack/SKILL.md"
  fi
  
  local skill_count=0
  for skill_dir in "$GSTACK_ROOT"/*/; do
    if [ -f "$skill_dir/SKILL.md.tmpl" ]; then
      local skill_name="$(basename "$skill_dir")"
      
      [ "$skill_name" = "node_modules" ] && continue
      [ "$skill_name" = "trae-skills" ] && continue
      [ "$skill_name" = ".agents" ] && continue
      [ "$skill_name" = ".github" ] && continue
      
      local trae_skill="$target_skills_dir/gstack-$skill_name"
      mkdir -p "$trae_skill"
      
      if [ -f "$skill_dir/SKILL.md" ]; then
        sed -e "s|~/.claude/skills/gstack|$target_gstack|g" \
            -e "s|\.claude/skills/gstack|$target_gstack|g" \
            -e "s|\$GSTACK_ROOT|$target_gstack|g" \
            -e "s|\$GSTACK_BIN|$target_gstack/bin|g" \
            -e "s|\$GSTACK_BROWSE|$target_gstack/browse/dist|g" \
            "$skill_dir/SKILL.md" > "$trae_skill/SKILL.md"
        ((skill_count++))
      fi
    fi
  done
  
  success "Created $skill_count Trae skills in $target_skills_dir"
}

create_trae_global_install() {
  info "Creating global Trae skills installation..."
  
  for target_dir in "${TRAE_SKILLS_DIRS[@]}"; do
    install_to_target "$target_dir"
  done
}

create_state_dir() {
  mkdir -p "$HOME/.gstack/projects"
  mkdir -p "$HOME/.gstack/analytics"
  success "Global state directory ready: ~/.gstack"
}

print_instructions() {
  echo ""
  echo "=========================================="
  echo "  gstack for Trae IDE - Global Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Skills installed to:"
  for target_dir in "${TRAE_SKILLS_DIRS[@]}"; do
    echo "  - $target_dir"
  done
  echo ""
  echo "Available skills:"
  echo "  - gstack (root skill with browser automation)"
  echo "  - gstack-review, gstack-ship, gstack-qa"
  echo "  - gstack-design-review, gstack-plan-ceo-review"
  echo "  - ... and more"
  echo ""
  echo "To use in Trae IDE:"
  echo "  1. Open Trae IDE Settings (Cmd+, or Ctrl+,)"
  echo "  2. Navigate to Skills/Agents configuration"
  echo "  3. Add skill directory path:"
  for target_dir in "${TRAE_SKILLS_DIRS[@]}"; do
    echo "     $target_dir"
  done
  echo ""
  echo "Or set environment variables:"
  echo "  # For ~/.trae/skills"
  echo "  export GSTACK_ROOT=\"\$HOME/.trae/skills/gstack\""
  echo "  export GSTACK_BIN=\"\$HOME/.trae/skills/gstack/bin\""
  echo "  export GSTACK_BROWSE=\"\$HOME/.trae/skills/gstack/browse/dist\""
  echo ""
  echo "  # For ~/.trae-cn/skills"
  echo "  export GSTACK_ROOT=\"\$HOME/.trae-cn/skills/gstack\""
  echo "  export GSTACK_BIN=\"\$HOME/.trae-cn/skills/gstack/bin\""
  echo "  export GSTACK_BROWSE=\"\$HOME/.trae-cn/skills/gstack/browse/dist\""
  echo ""
  echo "To update skills later, run:"
  echo "  cd $GSTACK_ROOT && git pull && ./trae-skills/global-install.sh"
  echo ""
}

main() {
  info "Starting gstack Trae global installation..."
  
  check_git
  check_bun
  build_browse
  install_playwright
  generate_skill_docs
  create_trae_global_install
  create_state_dir
  
  print_instructions
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Install gstack skills globally to:"
      echo "  - ~/.trae/skills"
      echo "  - ~/.trae-cn/skills"
      echo ""
      echo "Options:"
      echo "  --help, -h    Show this help message"
      echo ""
      exit 0
      ;;
    *) shift ;;
  esac
done

main
