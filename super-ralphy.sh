#!/usr/bin/env bash
# Super Ralphy - Enhanced autonomous AI coding loop
# Inspired by Ralph Wiggum (Anthropic) and Ralphy (michaelshimeles)
# https://github.com/sashabogi/super-ralphy

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Constants & Colors
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Default Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Task sources
PRD_FILE=""
YAML_FILE=""
GITHUB_REPO=""
GITHUB_LABEL=""
SINGLE_TASK=""

# AI Engine
ENGINE="claude"  # claude, opencode, cursor, codex, qwen, droid

# Super Ralphy features
ENABLE_AGENTS=false
ENABLE_SKILLS=false
ENABLE_ARGUS=false
ENABLE_BROWSER=false
ENABLE_QUALITY_GATES=false
ENABLE_NOTES=false
ENABLE_PM_MODE=false
ARGUS_REFRESH=false

# Browser settings
BROWSER_URL="http://localhost:3000"
BROWSER_HEADED=false
BROWSER_DEV_CMD=""

# Quality gate settings
GATE_TEST=true
GATE_LINT=true
GATE_TYPECHECK=false

# Execution settings
PARALLEL=false
MAX_PARALLEL=3
BRANCH_PER_TASK=false
BASE_BRANCH=""
CREATE_PR=false
DRAFT_PR=false

# Control settings
NO_TESTS=false
NO_LINT=false
NO_COMMIT=false
MAX_ITERATIONS=0
MAX_RETRIES=3
RETRY_DELAY=5
STRICT_MODE=false
DRY_RUN=false
VERBOSE=false

# Config
CONFIG_DIR=".super-ralphy"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SKILLS_DIR=".claude/skills"
AGENTS_DIR=".claude/agents"
NOTES_DIR="docs/claude/working-notes"

# State
CURRENT_TASK=""
CURRENT_AGENT="coder"
TASK_COUNT=0
ARGUS_TASK_COUNT=0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Logging Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log_info() {
  echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
  echo -e "${GREEN}[✓]${RESET} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${RESET} $1" >&2
}

log_debug() {
  if [[ "$VERBOSE" == true ]]; then
    echo -e "${MAGENTA}[DEBUG]${RESET} $1"
  fi
}

log_task() {
  echo -e "${CYAN}[TASK]${RESET} $1"
}

log_agent() {
  echo -e "${MAGENTA}[AGENT:$1]${RESET} $2"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Banner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_banner() {
  echo -e "${BOLD}${CYAN}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🦸 Super Ralphy v${VERSION}"
  echo "  Enhanced autonomous AI coding loop"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${RESET}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Help
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_help() {
  show_banner
  cat << 'EOF'
USAGE:
  super-ralphy [OPTIONS] [TASK]
  super-ralphy --prd PRD.md
  super-ralphy "add login button"

TASK SOURCES:
  --prd FILE              Markdown task file (default: PRD.md or TODO.md)
  --yaml FILE             YAML task file
  --github REPO           Use GitHub issues (owner/repo)
  --github-label TAG      Filter issues by label

SUPER RALPHY FEATURES:
  --agents                Enable sub-agent routing (coder/tester/reviewer/documenter)
  --skills                Enable skills injection from .claude/skills/
  --argus                 Enable Argus codebase intelligence
  --argus-refresh         Force Argus snapshot refresh
  --browser               Enable browser verification (requires agent-browser)
  --browser-url URL       Dev server URL (default: http://localhost:3000)
  --browser-headed        Show visible browser window
  --quality-gates         Run quality checks between tasks
  --gate-test             Run tests as quality gate
  --gate-lint             Run lint as quality gate
  --gate-typecheck        Run typecheck as quality gate
  --notes                 Write session working notes
  --pm-mode               Enforce PM mode (delegate only, never code directly)
  --install-skill NAME    Install a skill to .claude/skills/
  --install-argus         Install Argus MCP for codebase intelligence
  --install-browser       Install agent-browser for browser automation

EXECUTION:
  --parallel              Run tasks in parallel
  --max-parallel N        Max parallel agents (default: 3)
  --branch-per-task       Create branch per task
  --base-branch NAME      Base branch for branching
  --create-pr             Create PRs for branches
  --draft-pr              Create draft PRs

CONTROL:
  --no-tests              Skip test commands
  --no-lint               Skip lint commands
  --fast                  Skip tests + lint
  --no-commit             Don't auto-commit
  --max-iterations N      Stop after N tasks (0 = unlimited)
  --max-retries N         Retries per task (default: 3)
  --retry-delay N         Seconds between retries (default: 5)
  --strict                Stop on any failure
  --dry-run               Preview without executing
  -v, --verbose           Debug output

CONFIG:
  --init                  Setup .super-ralphy/ config
  --config                Show current config
  --add-rule "rule"       Add rule to config

ENGINES:
  --opencode              Use OpenCode
  --cursor                Use Cursor
  --codex                 Use Codex
  --qwen                  Use Qwen-Code
  --droid                 Use Factory Droid

EXAMPLES:
  super-ralphy "add dark mode"
  super-ralphy --prd PRD.md
  super-ralphy --agents --skills --browser "fix login form"
  super-ralphy --parallel --branch-per-task --create-pr
  super-ralphy --pm-mode --agents --quality-gates

EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Dependency Checks
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_dependencies() {
  local missing=()
  
  # Required: jq
  if ! command -v jq &>/dev/null; then
    missing+=("jq")
  fi
  
  # Check AI engine
  case "$ENGINE" in
    claude)
      if ! command -v claude &>/dev/null; then
        log_error "Claude Code CLI not found. Install from https://github.com/anthropics/claude-code"
        exit 1
      fi
      ;;
    opencode)
      if ! command -v opencode &>/dev/null; then
        log_error "OpenCode CLI not found. Install from https://opencode.ai/docs/"
        exit 1
      fi
      ;;
    cursor)
      if ! command -v cursor &>/dev/null && ! command -v agent &>/dev/null; then
        log_error "Cursor CLI not found. Install from https://cursor.com"
        exit 1
      fi
      ;;
    codex)
      if ! command -v codex &>/dev/null; then
        log_error "Codex CLI not found."
        exit 1
      fi
      ;;
    qwen)
      if ! command -v qwen &>/dev/null; then
        log_error "Qwen-Code CLI not found."
        exit 1
      fi
      ;;
    droid)
      if ! command -v droid &>/dev/null; then
        log_error "Factory Droid CLI not found. Install from https://docs.factory.ai/cli/getting-started/quickstart"
        exit 1
      fi
      ;;
  esac
  
  # Optional: yq for YAML
  if [[ -n "$YAML_FILE" ]] && ! command -v yq &>/dev/null; then
    missing+=("yq (for YAML tasks)")
  fi
  
  # Optional: gh for GitHub
  if [[ -n "$GITHUB_REPO" ]] && ! command -v gh &>/dev/null; then
    missing+=("gh (for GitHub issues)")
  fi
  
  # Optional: agent-browser
  if [[ "$ENABLE_BROWSER" == true ]] && ! command -v agent-browser &>/dev/null; then
    log_warn "agent-browser not found. Install with: npm install -g agent-browser && agent-browser install"
    ENABLE_BROWSER=false
  fi
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing dependencies: ${missing[*]}"
    exit 1
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Config Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

init_config() {
  log_info "Initializing Super Ralphy config..."
  
  mkdir -p "$CONFIG_DIR"
  
  # Auto-detect project settings
  local project_name=""
  local lang=""
  local framework=""
  local test_cmd=""
  local lint_cmd=""
  local build_cmd=""
  local dev_cmd=""
  
  # Detect from package.json
  if [[ -f "package.json" ]]; then
    project_name=$(jq -r '.name // "unknown"' package.json 2>/dev/null || echo "unknown")
    
    local deps=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys[]' package.json 2>/dev/null || true)
    
    if echo "$deps" | grep -q "typescript"; then
      lang="TypeScript"
    else
      lang="JavaScript"
    fi
    
    if echo "$deps" | grep -q "next"; then
      framework="Next.js"
    elif echo "$deps" | grep -q "react"; then
      framework="React"
    elif echo "$deps" | grep -q "vue"; then
      framework="Vue"
    elif echo "$deps" | grep -q "svelte"; then
      framework="Svelte"
    fi
    
    # Detect commands from scripts
    if jq -e '.scripts.test' package.json &>/dev/null; then
      test_cmd="npm test"
    fi
    if jq -e '.scripts.lint' package.json &>/dev/null; then
      lint_cmd="npm run lint"
    fi
    if jq -e '.scripts.build' package.json &>/dev/null; then
      build_cmd="npm run build"
    fi
    if jq -e '.scripts.dev' package.json &>/dev/null; then
      dev_cmd="npm run dev"
    fi
  fi
  
  # Create config file
  cat > "$CONFIG_FILE" << EOF
# Super Ralphy Configuration
# https://github.com/sashabogi/super-ralphy

project:
  name: "${project_name:-my-project}"
  language: "${lang:-Unknown}"
  framework: "${framework:-Unknown}"

commands:
  test: "${test_cmd}"
  lint: "${lint_cmd}"
  build: "${build_cmd}"
  dev: "${dev_cmd}"

rules:
  - "Keep changes focused and minimal"
  - "Do not refactor unrelated code"
  - "Write tests for new functionality"

boundaries:
  never_touch:
    - "*.lock"
    - ".env*"
    - "node_modules/**"

# Super Ralphy specific
agents:
  enabled: true
  coder: ".claude/agents/coder/AGENT.md"
  tester: ".claude/agents/tester/AGENT.md"
  reviewer: ".claude/agents/reviewer/AGENT.md"
  documenter: ".claude/agents/documenter/AGENT.md"

skills:
  enabled: true
  path: ".claude/skills"

argus:
  enabled: true
  snapshot: ".argus/snapshot.txt"
  refresh_interval: 5

browser:
  enabled: false
  url: "http://localhost:3000"
  headed: false
  dev_command: "${dev_cmd}"

quality_gates:
  enabled: true
  test: true
  lint: true
  typecheck: false
EOF

  log_success "Created $CONFIG_FILE"
  
  # Show what was detected
  echo ""
  echo -e "${BOLD}Detected:${RESET}"
  echo -e "  Project:   ${CYAN}${project_name:-unknown}${RESET}"
  [[ -n "$lang" ]] && echo -e "  Language:  ${CYAN}$lang${RESET}"
  [[ -n "$framework" ]] && echo -e "  Framework: ${CYAN}$framework${RESET}"
  [[ -n "$test_cmd" ]] && echo -e "  Test:      ${CYAN}$test_cmd${RESET}"
  [[ -n "$lint_cmd" ]] && echo -e "  Lint:      ${CYAN}$lint_cmd${RESET}"
  [[ -n "$dev_cmd" ]] && echo -e "  Dev:       ${CYAN}$dev_cmd${RESET}"
  echo ""
}

show_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"
  else
    log_warn "No config file found. Run 'super-ralphy --init' to create one."
  fi
}

add_rule() {
  local rule="$1"
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "No config file found. Run 'super-ralphy --init' first."
    exit 1
  fi
  
  if command -v yq &>/dev/null; then
    yq -i ".rules += [\"$rule\"]" "$CONFIG_FILE"
    log_success "Added rule: $rule"
  else
    log_error "yq is required to modify config. Install with: brew install yq"
    exit 1
  fi
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]] && command -v yq &>/dev/null; then
    # Load commands from config
    local test_cmd=$(yq -r '.commands.test // ""' "$CONFIG_FILE" 2>/dev/null)
    local lint_cmd=$(yq -r '.commands.lint // ""' "$CONFIG_FILE" 2>/dev/null)
    local dev_cmd=$(yq -r '.commands.dev // ""' "$CONFIG_FILE" 2>/dev/null)
    
    [[ -n "$dev_cmd" && -z "$BROWSER_DEV_CMD" ]] && BROWSER_DEV_CMD="$dev_cmd"
    
    # Load browser settings
    local browser_url=$(yq -r '.browser.url // ""' "$CONFIG_FILE" 2>/dev/null)
    [[ -n "$browser_url" ]] && BROWSER_URL="$browser_url"
    
    log_debug "Loaded config from $CONFIG_FILE"
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sub-Agent System
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_agent() {
  local task="$1"
  local task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')
  
  # Tester keywords
  if echo "$task_lower" | grep -qE '\b(test|spec|coverage|jest|vitest|pytest|unittest)\b'; then
    echo "tester"
    return
  fi
  
  # Reviewer keywords
  if echo "$task_lower" | grep -qE '\b(review|audit|verify|security|vulnerability|check)\b'; then
    echo "reviewer"
    return
  fi
  
  # Documenter keywords
  if echo "$task_lower" | grep -qE '\b(document|readme|docs|jsdoc|comment|changelog)\b'; then
    echo "documenter"
    return
  fi
  
  # Browser keywords
  if echo "$task_lower" | grep -qE '\b(browser|ui|visual|screenshot|e2e|cypress|playwright)\b'; then
    echo "browser"
    return
  fi
  
  # Default to coder
  echo "coder"
}

get_agent_prompt() {
  local agent="$1"
  local task="$2"
  
  local agent_file="$AGENTS_DIR/$agent/AGENT.md"
  local agent_prompt=""
  
  if [[ -f "$agent_file" ]]; then
    agent_prompt=$(cat "$agent_file")
  else
    # Default prompts
    case "$agent" in
      tester)
        agent_prompt="You are a testing specialist. Focus on writing comprehensive tests, improving coverage, and ensuring test quality. Use appropriate testing frameworks for the project."
        ;;
      reviewer)
        agent_prompt="You are a code reviewer. Focus on code quality, security vulnerabilities, performance issues, and best practices. Provide actionable feedback."
        ;;
      documenter)
        agent_prompt="You are a documentation specialist. Focus on clear, accurate documentation including README files, API docs, code comments, and user guides."
        ;;
      browser)
        agent_prompt="You are a UI verification specialist. Use agent-browser to verify UI changes work correctly. Take screenshots and validate element presence."
        ;;
      *)
        agent_prompt="You are a skilled developer. Implement the task efficiently following project conventions."
        ;;
    esac
  fi
  
  echo "$agent_prompt"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Skills Injection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_skills() {
  local task="$1"
  local task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')
  local skills=()
  
  # Convex
  if echo "$task_lower" | grep -qE '\b(convex|mutation|query|schema|action)\b'; then
    skills+=("convex")
  fi
  
  # Next.js
  if echo "$task_lower" | grep -qE '\b(nextjs|next|page|app router|server action)\b'; then
    skills+=("nextjs")
  fi
  
  # React
  if echo "$task_lower" | grep -qE '\b(react|component|hook|useState|useEffect)\b'; then
    skills+=("react")
  fi
  
  # Testing
  if echo "$task_lower" | grep -qE '\b(test|spec|coverage|jest|vitest)\b'; then
    skills+=("testing")
  fi
  
  # Browser
  if echo "$task_lower" | grep -qE '\b(browser|agent-browser|ui|visual|e2e)\b'; then
    skills+=("agent-browser")
  fi
  
  # TypeScript
  if echo "$task_lower" | grep -qE '\b(typescript|types|interface|type)\b'; then
    skills+=("typescript")
  fi
  
  echo "${skills[*]}"
}

load_skills() {
  local skills="$1"
  local skill_content=""
  
  for skill in $skills; do
    local skill_file="$SKILLS_DIR/$skill/SKILL.md"
    if [[ -f "$skill_file" ]]; then
      skill_content+="
--- SKILL: $skill ---
$(cat "$skill_file")
"
      log_debug "Loaded skill: $skill"
    fi
  done
  
  echo "$skill_content"
}

install_skill() {
  local skill_name="$1"
  
  mkdir -p "$SKILLS_DIR/$skill_name"
  
  case "$skill_name" in
    agent-browser)
      log_info "Installing agent-browser skill..."
      curl -fsSL -o "$SKILLS_DIR/agent-browser/SKILL.md" \
        "https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md"
      log_success "Installed agent-browser skill"
      ;;
    *)
      log_error "Unknown skill: $skill_name"
      log_info "Try: npx add-skill vercel-labs/agent-skills"
      exit 1
      ;;
  esac
}

install_argus() {
  log_info "Installing Argus MCP..."
  
  # Check if npm is available
  if ! command -v npm &>/dev/null; then
    log_error "npm is required to install Argus"
    exit 1
  fi
  
  # Install from GitHub
  if npm install -g github:sashabogi/argus-mcp 2>/dev/null; then
    log_success "Argus MCP installed globally"
  else
    log_warn "Global install failed, trying local install..."
    npm install github:sashabogi/argus-mcp 2>/dev/null || {
      log_error "Failed to install Argus MCP"
      log_info "Manual install: npm install github:sashabogi/argus-mcp"
      exit 1
    }
    log_success "Argus MCP installed locally"
  fi
  
  # Verify installation
  if command -v argus &>/dev/null; then
    log_success "Argus is ready: $(argus --version 2>/dev/null || echo 'installed')"
  else
    log_info "Argus installed. You may need to restart your terminal or add node_modules/.bin to PATH"
  fi
}

install_agent_browser() {
  log_info "Installing agent-browser..."
  
  if ! command -v npm &>/dev/null; then
    log_error "npm is required to install agent-browser"
    exit 1
  fi
  
  npm install -g agent-browser || {
    log_error "Failed to install agent-browser"
    exit 1
  }
  
  log_info "Downloading Chromium (this may take a minute)..."
  agent-browser install || {
    log_warn "Chromium download failed. Run 'agent-browser install' manually."
  }
  
  log_success "agent-browser installed"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argus Integration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

refresh_argus() {
  local snapshot=".argus/snapshot.txt"
  
  if command -v argus &>/dev/null || [[ -d "node_modules/argus-mcp" ]]; then
    log_info "Refreshing Argus snapshot..."
    
    mkdir -p .argus
    
    # Try different Argus invocations
    if command -v argus &>/dev/null; then
      argus snapshot --output "$snapshot" 2>/dev/null || true
    elif [[ -f "node_modules/.bin/argus" ]]; then
      node_modules/.bin/argus snapshot --output "$snapshot" 2>/dev/null || true
    fi
    
    if [[ -f "$snapshot" ]]; then
      log_success "Argus snapshot refreshed"
      ARGUS_TASK_COUNT=0
    fi
  else
    log_debug "Argus not available"
  fi
}

check_argus_refresh() {
  if [[ "$ENABLE_ARGUS" == true ]]; then
    ((ARGUS_TASK_COUNT++))
    
    # Refresh every 5 tasks by default
    local refresh_interval=5
    if [[ -f "$CONFIG_FILE" ]] && command -v yq &>/dev/null; then
      refresh_interval=$(yq -r '.argus.refresh_interval // 5' "$CONFIG_FILE" 2>/dev/null)
    fi
    
    if [[ $ARGUS_TASK_COUNT -ge $refresh_interval ]] || [[ "$ARGUS_REFRESH" == true ]]; then
      refresh_argus
    fi
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Browser Automation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

start_dev_server() {
  if [[ -n "$BROWSER_DEV_CMD" ]]; then
    log_info "Starting dev server: $BROWSER_DEV_CMD"
    
    # Start in background
    $BROWSER_DEV_CMD &
    DEV_SERVER_PID=$!
    
    # Wait for server to be ready
    local max_wait=30
    local waited=0
    while ! curl -s "$BROWSER_URL" >/dev/null 2>&1; do
      sleep 1
      ((waited++))
      if [[ $waited -ge $max_wait ]]; then
        log_warn "Dev server didn't start in time"
        break
      fi
    done
    
    log_debug "Dev server ready (PID: $DEV_SERVER_PID)"
  fi
}

stop_dev_server() {
  if [[ -n "${DEV_SERVER_PID:-}" ]]; then
    log_debug "Stopping dev server (PID: $DEV_SERVER_PID)"
    kill "$DEV_SERVER_PID" 2>/dev/null || true
  fi
}

verify_browser() {
  local url="${1:-$BROWSER_URL}"
  local elements="${2:-}"
  
  if [[ "$ENABLE_BROWSER" != true ]]; then
    return 0
  fi
  
  log_info "Verifying in browser: $url"
  
  # Open page
  local headed_flag=""
  [[ "$BROWSER_HEADED" == true ]] && headed_flag="--headed"
  
  agent-browser open "$url" $headed_flag 2>/dev/null || {
    log_warn "Failed to open browser"
    return 1
  }
  
  # Get snapshot
  local snapshot
  snapshot=$(agent-browser snapshot -i --json 2>/dev/null) || {
    log_warn "Failed to get browser snapshot"
    agent-browser close 2>/dev/null || true
    return 1
  }
  
  log_debug "Browser snapshot: ${snapshot:0:200}..."
  
  # Verify elements if specified
  if [[ -n "$elements" ]]; then
    for element in $elements; do
      if ! echo "$snapshot" | grep -q "$element"; then
        log_warn "Element not found: $element"
      fi
    done
  fi
  
  # Take screenshot
  local screenshot_dir=".super-ralphy/screenshots"
  mkdir -p "$screenshot_dir"
  local screenshot_file="$screenshot_dir/$(date +%Y%m%d-%H%M%S).png"
  agent-browser screenshot "$screenshot_file" 2>/dev/null && \
    log_debug "Screenshot saved: $screenshot_file"
  
  # Close browser
  agent-browser close 2>/dev/null || true
  
  log_success "Browser verification complete"
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Quality Gates
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_quality_gates() {
  if [[ "$ENABLE_QUALITY_GATES" != true ]]; then
    return 0
  fi
  
  local failed=false
  
  # Run tests
  if [[ "$GATE_TEST" == true && "$NO_TESTS" != true ]]; then
    log_info "Running tests..."
    if [[ -f "package.json" ]] && jq -e '.scripts.test' package.json &>/dev/null; then
      if ! npm test 2>/dev/null; then
        log_error "Tests failed"
        failed=true
      else
        log_success "Tests passed"
      fi
    fi
  fi
  
  # Run lint
  if [[ "$GATE_LINT" == true && "$NO_LINT" != true ]]; then
    log_info "Running lint..."
    if [[ -f "package.json" ]] && jq -e '.scripts.lint' package.json &>/dev/null; then
      if ! npm run lint 2>/dev/null; then
        log_error "Lint failed"
        failed=true
      else
        log_success "Lint passed"
      fi
    fi
  fi
  
  # Run typecheck
  if [[ "$GATE_TYPECHECK" == true ]]; then
    log_info "Running typecheck..."
    if [[ -f "tsconfig.json" ]]; then
      if ! npx tsc --noEmit 2>/dev/null; then
        log_error "Typecheck failed"
        failed=true
      else
        log_success "Typecheck passed"
      fi
    fi
  fi
  
  if [[ "$failed" == true && "$STRICT_MODE" == true ]]; then
    log_error "Quality gates failed in strict mode"
    return 1
  fi
  
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Working Notes
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

init_notes() {
  if [[ "$ENABLE_NOTES" == true ]]; then
    mkdir -p "$NOTES_DIR"
    NOTES_FILE="$NOTES_DIR/session-$(date +%Y-%m-%d-%H%M%S).md"
    
    cat > "$NOTES_FILE" << EOF
# Super Ralphy Session Notes
**Started:** $(date)
**Engine:** $ENGINE
**Features:** agents=$ENABLE_AGENTS, skills=$ENABLE_SKILLS, argus=$ENABLE_ARGUS, browser=$ENABLE_BROWSER

---

## Tasks

EOF
    log_debug "Notes file: $NOTES_FILE"
  fi
}

write_note() {
  local content="$1"
  
  if [[ "$ENABLE_NOTES" == true && -n "${NOTES_FILE:-}" ]]; then
    echo "$content" >> "$NOTES_FILE"
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Task Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_markdown_tasks() {
  local file="$1"
  local tasks=()
  
  while IFS= read -r line; do
    # Match unchecked markdown tasks: - [ ] task
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]](.+)$ ]]; then
      tasks+=("${BASH_REMATCH[1]}")
    fi
  done < "$file"
  
  printf '%s\n' "${tasks[@]}"
}

parse_yaml_tasks() {
  local file="$1"
  
  if ! command -v yq &>/dev/null; then
    log_error "yq is required for YAML tasks"
    exit 1
  fi
  
  yq -r '.tasks[] | select(.completed != true) | .title' "$file" 2>/dev/null
}

get_tasks() {
  local tasks=()
  
  if [[ -n "$SINGLE_TASK" ]]; then
    tasks=("$SINGLE_TASK")
  elif [[ -n "$YAML_FILE" ]]; then
    mapfile -t tasks < <(parse_yaml_tasks "$YAML_FILE")
  elif [[ -n "$PRD_FILE" ]]; then
    mapfile -t tasks < <(parse_markdown_tasks "$PRD_FILE")
  elif [[ -n "$GITHUB_REPO" ]]; then
    # Fetch from GitHub
    local label_filter=""
    [[ -n "$GITHUB_LABEL" ]] && label_filter="--label $GITHUB_LABEL"
    mapfile -t tasks < <(gh issue list --repo "$GITHUB_REPO" --state open $label_filter --json title --jq '.[].title' 2>/dev/null)
  else
    # Auto-detect PRD file
    for f in PRD.md TODO.md tasks.md; do
      if [[ -f "$f" ]]; then
        PRD_FILE="$f"
        mapfile -t tasks < <(parse_markdown_tasks "$PRD_FILE")
        break
      fi
    done
  fi
  
  printf '%s\n' "${tasks[@]}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Task Execution
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

build_prompt() {
  local task="$1"
  local agent="$2"
  local prompt=""
  
  # PM mode prefix
  if [[ "$ENABLE_PM_MODE" == true ]]; then
    prompt+="You are operating in PM MODE. You MUST delegate all coding tasks to appropriate sub-agents. Do NOT write code directly. Instead, create clear task specifications for the coder, tester, reviewer, or documenter agents.

"
  fi
  
  # Agent prompt
  if [[ "$ENABLE_AGENTS" == true ]]; then
    local agent_prompt=$(get_agent_prompt "$agent" "$task")
    prompt+="$agent_prompt

"
  fi
  
  # Skills
  if [[ "$ENABLE_SKILLS" == true ]]; then
    local skills=$(detect_skills "$task")
    if [[ -n "$skills" ]]; then
      local skill_content=$(load_skills "$skills")
      if [[ -n "$skill_content" ]]; then
        prompt+="$skill_content

"
      fi
    fi
  fi
  
  # Load rules from config
  if [[ -f "$CONFIG_FILE" ]] && command -v yq &>/dev/null; then
    local rules=$(yq -r '.rules[]' "$CONFIG_FILE" 2>/dev/null | sed 's/^/- /')
    if [[ -n "$rules" ]]; then
      prompt+="RULES:
$rules

"
    fi
  fi
  
  # The actual task
  prompt+="TASK: $task

Complete this task. Keep changes focused and minimal."

  echo "$prompt"
}

run_engine() {
  local prompt="$1"
  local result=""
  
  case "$ENGINE" in
    claude)
      result=$(claude -p "$prompt" --dangerously-skip-permissions 2>&1) || true
      ;;
    opencode)
      result=$(echo "$prompt" | opencode --approval-mode full-auto 2>&1) || true
      ;;
    cursor)
      if command -v agent &>/dev/null; then
        result=$(echo "$prompt" | agent --force 2>&1) || true
      else
        result=$(echo "$prompt" | cursor agent --force 2>&1) || true
      fi
      ;;
    codex)
      result=$(echo "$prompt" | codex 2>&1) || true
      ;;
    qwen)
      result=$(echo "$prompt" | qwen --approval-mode yolo 2>&1) || true
      ;;
    droid)
      result=$(droid exec "$prompt" --auto medium 2>&1) || true
      ;;
  esac
  
  echo "$result"
}

execute_task() {
  local task="$1"
  local retries=0
  
  CURRENT_TASK="$task"
  ((TASK_COUNT++))
  
  # Detect agent
  if [[ "$ENABLE_AGENTS" == true ]]; then
    CURRENT_AGENT=$(detect_agent "$task")
  else
    CURRENT_AGENT="coder"
  fi
  
  log_task "[$TASK_COUNT] $task"
  [[ "$ENABLE_AGENTS" == true ]] && log_agent "$CURRENT_AGENT" "Handling task"
  
  # Write to notes
  write_note "### Task $TASK_COUNT: $task
- Agent: $CURRENT_AGENT
- Started: $(date)
"
  
  # Check Argus refresh
  check_argus_refresh
  
  # Build prompt
  local prompt=$(build_prompt "$task" "$CURRENT_AGENT")
  log_debug "Prompt length: ${#prompt} chars"
  
  # Dry run
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would execute task with $ENGINE"
    log_debug "Prompt: ${prompt:0:500}..."
    return 0
  fi
  
  # Execute with retries
  while [[ $retries -lt $MAX_RETRIES ]]; do
    log_info "Executing with $ENGINE..."
    
    local result
    result=$(run_engine "$prompt")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
      log_success "Task completed"
      write_note "- Status: ✅ Completed
- Finished: $(date)
"
      
      # Run quality gates
      run_quality_gates || {
        if [[ "$STRICT_MODE" == true ]]; then
          return 1
        fi
      }
      
      # Browser verification
      if [[ "$ENABLE_BROWSER" == true ]]; then
        verify_browser
      fi
      
      # Commit if enabled
      if [[ "$NO_COMMIT" != true ]]; then
        git add -A 2>/dev/null || true
        git commit -m "feat: $task" 2>/dev/null || true
      fi
      
      return 0
    fi
    
    ((retries++))
    log_warn "Task failed, retry $retries/$MAX_RETRIES"
    sleep "$RETRY_DELAY"
  done
  
  log_error "Task failed after $MAX_RETRIES retries"
  write_note "- Status: ❌ Failed after $MAX_RETRIES retries
"
  
  return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Loop
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_loop() {
  local tasks
  mapfile -t tasks < <(get_tasks)
  
  if [[ ${#tasks[@]} -eq 0 ]]; then
    log_error "No tasks found"
    exit 1
  fi
  
  log_info "Found ${#tasks[@]} tasks"
  
  # Initialize
  init_notes
  
  # Initial Argus refresh
  if [[ "$ARGUS_REFRESH" == true ]]; then
    refresh_argus
  fi
  
  # Start dev server if browser enabled
  if [[ "$ENABLE_BROWSER" == true && -n "$BROWSER_DEV_CMD" ]]; then
    start_dev_server
    trap stop_dev_server EXIT
  fi
  
  # Execute tasks
  local completed=0
  local failed=0
  
  for task in "${tasks[@]}"; do
    # Check max iterations
    if [[ $MAX_ITERATIONS -gt 0 && $completed -ge $MAX_ITERATIONS ]]; then
      log_info "Reached max iterations ($MAX_ITERATIONS)"
      break
    fi
    
    if execute_task "$task"; then
      ((completed++))
    else
      ((failed++))
      if [[ "$STRICT_MODE" == true ]]; then
        log_error "Stopping due to failure (strict mode)"
        break
      fi
    fi
  done
  
  # Summary
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}Summary${RESET}"
  echo -e "  Completed: ${GREEN}$completed${RESET}"
  echo -e "  Failed:    ${RED}$failed${RESET}"
  echo -e "  Total:     ${#tasks[@]}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  
  # Write summary to notes
  write_note "
---

## Summary
- Completed: $completed
- Failed: $failed
- Total: ${#tasks[@]}
- Ended: $(date)
"
  
  if [[ "$ENABLE_NOTES" == true ]]; then
    log_info "Notes saved to: $NOTES_FILE"
  fi
  
  [[ $failed -gt 0 ]] && return 1
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argument Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      --version)
        echo "Super Ralphy v$VERSION"
        exit 0
        ;;
      
      # Task sources
      --prd)
        PRD_FILE="$2"
        shift 2
        ;;
      --yaml)
        YAML_FILE="$2"
        shift 2
        ;;
      --github)
        GITHUB_REPO="$2"
        shift 2
        ;;
      --github-label)
        GITHUB_LABEL="$2"
        shift 2
        ;;
      
      # Super Ralphy features
      --agents)
        ENABLE_AGENTS=true
        shift
        ;;
      --skills)
        ENABLE_SKILLS=true
        shift
        ;;
      --argus)
        ENABLE_ARGUS=true
        shift
        ;;
      --argus-refresh)
        ARGUS_REFRESH=true
        ENABLE_ARGUS=true
        shift
        ;;
      --browser)
        ENABLE_BROWSER=true
        shift
        ;;
      --browser-url)
        BROWSER_URL="$2"
        ENABLE_BROWSER=true
        shift 2
        ;;
      --browser-headed)
        BROWSER_HEADED=true
        ENABLE_BROWSER=true
        shift
        ;;
      --quality-gates)
        ENABLE_QUALITY_GATES=true
        shift
        ;;
      --gate-test)
        GATE_TEST=true
        ENABLE_QUALITY_GATES=true
        shift
        ;;
      --gate-lint)
        GATE_LINT=true
        ENABLE_QUALITY_GATES=true
        shift
        ;;
      --gate-typecheck)
        GATE_TYPECHECK=true
        ENABLE_QUALITY_GATES=true
        shift
        ;;
      --notes)
        ENABLE_NOTES=true
        shift
        ;;
      --pm-mode)
        ENABLE_PM_MODE=true
        ENABLE_AGENTS=true
        shift
        ;;
      --install-skill)
        install_skill "$2"
        exit 0
        ;;
      --install-argus)
        install_argus
        exit 0
        ;;
      --install-browser)
        install_agent_browser
        exit 0
        ;;
      
      # Execution
      --parallel)
        PARALLEL=true
        shift
        ;;
      --max-parallel)
        MAX_PARALLEL="$2"
        shift 2
        ;;
      --branch-per-task)
        BRANCH_PER_TASK=true
        shift
        ;;
      --base-branch)
        BASE_BRANCH="$2"
        shift 2
        ;;
      --create-pr)
        CREATE_PR=true
        shift
        ;;
      --draft-pr)
        DRAFT_PR=true
        CREATE_PR=true
        shift
        ;;
      
      # Control
      --no-tests)
        NO_TESTS=true
        shift
        ;;
      --no-lint)
        NO_LINT=true
        shift
        ;;
      --fast)
        NO_TESTS=true
        NO_LINT=true
        shift
        ;;
      --no-commit)
        NO_COMMIT=true
        shift
        ;;
      --max-iterations)
        MAX_ITERATIONS="$2"
        shift 2
        ;;
      --max-retries)
        MAX_RETRIES="$2"
        shift 2
        ;;
      --retry-delay)
        RETRY_DELAY="$2"
        shift 2
        ;;
      --strict)
        STRICT_MODE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      
      # Config
      --init)
        init_config
        exit 0
        ;;
      --config)
        show_config
        exit 0
        ;;
      --add-rule)
        add_rule "$2"
        exit 0
        ;;
      
      # Engines
      --opencode)
        ENGINE="opencode"
        shift
        ;;
      --cursor)
        ENGINE="cursor"
        shift
        ;;
      --codex)
        ENGINE="codex"
        shift
        ;;
      --qwen)
        ENGINE="qwen"
        shift
        ;;
      --droid)
        ENGINE="droid"
        shift
        ;;
      
      # Unknown option
      -*)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
      
      # Single task
      *)
        SINGLE_TASK="$1"
        shift
        ;;
    esac
  done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Entry Point
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  parse_args "$@"
  
  show_banner
  
  check_dependencies
  load_config
  
  main_loop
}

main "$@"
