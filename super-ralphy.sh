#!/usr/bin/env zsh
# Super Ralphy - Parallel AI Coding with Git Worktrees
# The REAL upgrade over Ralphy: parallel execution, worktrees, AI merge
# https://github.com/sashabogi/super-ralphy

setopt ERR_EXIT PIPE_FAIL NO_UNSET

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Constants & Colors
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERSION="2.0.0"
SCRIPT_DIR="${0:A:h}"  # zsh equivalent of BASH_SOURCE dirname

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Task sources
PRD_FILE=""
YAML_FILE=""
SINGLE_TASK=""

# AI Engine
ENGINE="claude"

# Super Ralphy features
ENABLE_AGENTS=false
ENABLE_SKILLS=false
ENABLE_ARGUS=false
ENABLE_QUALITY_GATES=false
ENABLE_NOTES=false
ENABLE_BROWSER=false
ARGUS_REFRESH=false

# Browser verification
BROWSER_URL="http://localhost:3000"
BROWSER_HEADED=false
BROWSER_DEV_COMMAND=""

# Parallel execution (THE KEY FEATURE)
PARALLEL=false
MAX_PARALLEL=3
USE_WORKTREES=true
WORKTREE_DIR=".worktrees"
BASE_BRANCH=""
AI_MERGE=true

# Quality gates
GATE_TEST=true
GATE_LINT=true
GATE_TYPECHECK=false

# Control
NO_COMMIT=false
MAX_RETRIES=3
STRICT_MODE=false
DRY_RUN=false
VERBOSE=false

# Directories
CONFIG_DIR=".super-ralphy"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SKILLS_DIR=".claude/skills"
AGENTS_DIR=".claude/agents"
NOTES_DIR="docs/claude/working-notes"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Config Storage
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

typeset -A CONFIG_PROJECT     # name, language, framework
typeset -A CONFIG_COMMANDS    # test, lint, build, dev
typeset -a CONFIG_RULES       # list of rules
typeset -a CONFIG_BOUNDARIES  # never_touch patterns
typeset -A CONFIG_AGENTS      # enabled, coder, tester, reviewer, documenter
typeset -A CONFIG_SKILLS      # enabled, path
typeset -A CONFIG_ARGUS       # enabled, snapshot, refresh_interval
typeset -A CONFIG_BROWSER     # enabled, url, headed, dev_command
typeset -A CONFIG_QUALITY_GATES  # enabled, test, lint, typecheck

# Config defaults
CONFIG_LOADED=false


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Config Storage
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

typeset -A CONFIG_PROJECT     # name, language, framework
typeset -A CONFIG_COMMANDS    # test, lint, build, dev
typeset -a CONFIG_RULES       # list of rules
typeset -a CONFIG_BOUNDARIES  # never_touch patterns
typeset -A CONFIG_AGENTS      # enabled, coder, tester, reviewer, documenter
typeset -A CONFIG_SKILLS      # enabled, path
typeset -A CONFIG_ARGUS       # enabled, snapshot, refresh_interval
typeset -A CONFIG_BROWSER     # enabled, url, headed, dev_command
typeset -A CONFIG_QUALITY_GATES  # enabled, test, lint, typecheck

# State
typeset -A TASK_DEPS          # task -> space-separated dependencies
typeset -A TASK_STATUS        # task -> pending|running|done|failed
typeset -A TASK_BRANCH        # task -> branch name
typeset -A TASK_WORKTREE      # task -> worktree path
typeset -A TASK_PID           # task -> background PID
typeset -a EXECUTION_ORDER    # topologically sorted tasks

# Browser state
typeset -A BROWSER_IDS        # task_id -> browser ID from agent-browser
typeset -A DEV_SERVER_PIDS    # task_id -> dev server PID
BROWSER_SCREENSHOTS_DIR=".super-ralphy/screenshots"

# YAML-specific task attributes
typeset -A TASK_AGENT         # task -> agent type (coder, tester, browser, etc.)
typeset -A TASK_SKILLS        # task -> comma-separated skills
typeset -A TASK_VERIFY_BROWSER # task -> true/false for browser verification
typeset -A TASK_VERIFY_URL    # task -> URL path for verification
typeset -A TASK_VERIFY_ELEMENTS # task -> space-separated CSS selectors to verify
typeset -A TASK_PARALLEL_GROUP # task -> parallel group number
typeset -A TASK_RAW_DEPS      # task -> raw dependency list from YAML
typeset -A _YAML_GROUP_TASKS  # internal: group -> space-separated task IDs

RUNNING_COUNT=0
SESSION_FILE=""               # Current working notes session file
SESSION_START_TIME=""         # Session start timestamp

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Logging
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log_info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}[✓]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; }
log_debug()   { if [[ "$VERBOSE" == true ]]; then echo -e "${DIM}[DEBUG]${RESET} $1"; fi; return 0; }
log_task()    { echo -e "${CYAN}[TASK]${RESET} $1"; }
log_parallel(){ echo -e "${MAGENTA}[PARALLEL]${RESET} $1"; }
log_worktree(){ echo -e "${YELLOW}[WORKTREE]${RESET} $1"; }
log_merge()   { echo -e "${GREEN}[MERGE]${RESET} $1"; }
log_browser() { echo -e "${BOLD}${MAGENTA}[BROWSER]${RESET} $1"; }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Banner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_banner() {
  echo -e "${BOLD}${CYAN}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🦸 Super Ralphy v${VERSION}"
  echo "  Parallel AI Coding with Git Worktrees"
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
  super-ralphy --prd PRD.md --parallel

PROJECT CONFIG:
  --init                  Auto-detect and create .super-ralphy/config.yaml
  --config                Show current project configuration
  --add-rule "rule"       Add a rule to the project config

TASK SOURCES:
  --prd FILE              Markdown PRD with tasks
  --yaml FILE             YAML task file
  "task description"      Single task

PARALLEL EXECUTION:
  --parallel              Enable parallel task execution
  --max-parallel N        Max concurrent agents (default: 3)
  --worktrees             Use git worktrees
  --ai-merge              Use AI to resolve merge conflicts

FEATURES:
  --agents                Enable sub-agent routing
  --skills                Enable skills injection
  --argus                 Enable Argus codebase intelligence
  --browser               Enable browser verification (requires agent-browser)
  --browser-url URL       Dev server URL for browser verification
  --browser-headed        Show visible browser window
  --quality-gates         Run quality gates (test/lint/typecheck)
  --notes                 Write session working notes

CONTROL:
  --no-commit             Don't auto-commit
  --strict                Stop on any failure
  --dry-run               Preview without executing
  -v, --verbose           Debug output

EXAMPLES:
  super-ralphy --init                    # Initialize project config
  super-ralphy --config                  # Show config
  super-ralphy --add-rule "strict mode"  # Add rule
  super-ralphy --prd PRD.md --parallel   # Parallel execution
  super-ralphy --browser "fix login"     # Verify with browser after coding
EOF
}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Dependency Checks
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_dependencies() {
  local missing=()
  
  command -v jq &>/dev/null || missing+=("jq")
  command -v git &>/dev/null || missing+=("git")
  
  case "$ENGINE" in
    claude)
      command -v claude &>/dev/null || {
        log_error "Claude Code CLI not found"
        exit 1
      }
      ;;
  esac
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing: ${missing[*]}"
    exit 1
  fi
  
  # Check we're in a git repo
  if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not in a git repository"
    exit 1
  fi
}

# Project Config Management functions

# Parse a YAML key value using yq or simple sed fallback
# For dotted keys like "project.name" or "agents.enabled"
_yaml_get_value() {
  local file="$1" key="$2"
  if command -v yq >/dev/null 2>&1; then
    yq eval ".$key" "$file" 2>/dev/null || true
    return 0
  fi

  # Simple sed-based fallback for 2-part keys like "section.key"
  local section="${key%%.*}"
  local target="${key##*.}"

  # Extract section, then find the key
  sed -n "/^${section}:/,/^[A-Za-z_]/p" "$file" 2>/dev/null | \
    sed -n '1,/^[A-Za-z_]/p' | \
    sed -n "/^[[:space:]]*${target}:/p" | \
    head -1 | \
    sed "s/^[[:space:]]*[^:]*:[[:space:]]*//; s/^[\"']//; s/[\"']$//"
  return 0
}

# Parse a YAML list - returns one item per line
_yaml_get_list() {
  local file="$1" key="$2"
  if command -v yq >/dev/null 2>&1; then
    yq eval ".$key[]" "$file" 2>/dev/null || true
    return 0
  fi

  # Fallback: Find section and extract list items
  sed -n "/^${key}:/,/^[A-Za-z_]/p" "$file" 2>/dev/null | \
    sed -n '1,/^[A-Za-z_]/p' | \
    grep -E '^[ \t]*-' | \
    sed 's/^[ \t]*-[ \t]*//; s/^["\x27]//; s/["\x27]$//' || true
  return 0
}

# Check if YAML key is true
_yaml_get_bool() {
  local file="$1" key="$2" val
  val=$(_yaml_get_value "$file" "$key")
  [[ "$val" == "true" ]]
  return 0  # Always return 0, even if false
}

# Auto-detect project settings
detect_project_settings() {
  local name framework language
  local test lint build dev
  name="$(basename "$(pwd)")"
  
  # Detect project type
  if [[ -f package.json ]]; then
    language="TypeScript/JavaScript"
    if grep -q '"next"' package.json 2>/dev/null; then
      framework="Next.js"
    elif grep -q '"react"' package.json 2>/dev/null; then
      framework="React"
    elif grep -q '"vue"' package.json 2>/dev/null; then
      framework="Vue"
    else
      framework="Node.js"
    fi
    test="$(jq -r '.scripts.test // empty' package.json 2>/dev/null)"
    lint="$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)"
    build="$(jq -r '.scripts.build // empty' package.json 2>/dev/null)"
    dev="$(jq -r '.scripts.dev // .scripts.develop // empty' package.json 2>/dev/null)"
  elif [[ -f requirements.txt ]] || [[ -f pyproject.toml ]]; then
    language="Python"
    if [[ -f manage.py ]]; then
      framework="Django"
    else
      framework="Python"
    fi
    test="pytest"
    lint="ruff check"
  elif [[ -f go.mod ]]; then
    language="Go"
    framework="Go"
    test="go test ./..."
    lint="golangci-lint run"
    build="go build"
    dev="go run"
  elif [[ -f Cargo.toml ]]; then
    language="Rust"
    framework="Rust"
    test="cargo test"
    lint="cargo clippy"
    build="cargo build"
    dev="cargo run"
  else
    language="Unknown"
    framework="Unknown"
  fi

  echo "project_name=$name"
  echo "language=$language"
  echo "framework=$framework"
  echo "test_cmd=$test"
  echo "lint_cmd=$lint"
  echo "build_cmd=$build"
  echo "dev_cmd=$dev"
}

# Load config from .super-ralphy/config.yaml
load_config() {
  local cf="$CONFIG_FILE"
  [[ ! -f "$cf" ]] && return 0  # No config file is OK, just use defaults

  log_debug "Loading config from $cf"

  local pn lang frm
  pn=$(_yaml_get_value "$cf" "project.name")
  lang=$(_yaml_get_value "$cf" "project.language")
  frm=$(_yaml_get_value "$cf" "project.framework")
  
  [[ -n "$pn" ]] && CONFIG_PROJECT[name]="$pn"
  [[ -n "$lang" ]] && CONFIG_PROJECT[language]="$lang"
  [[ -n "$frm" ]] && CONFIG_PROJECT[framework]="$frm"
  
  local t l b d
  t=$(_yaml_get_value "$cf" "commands.test")
  l=$(_yaml_get_value "$cf" "commands.lint")
  b=$(_yaml_get_value "$cf" "commands.build")
  d=$(_yaml_get_value "$cf" "commands.dev")
  
  [[ -n "$t" ]] && CONFIG_COMMANDS[test]="$t"
  [[ -n "$l" ]] && CONFIG_COMMANDS[lint]="$l"
  [[ -n "$b" ]] && CONFIG_COMMANDS[build]="$b"
  [[ -n "$d" ]] && CONFIG_COMMANDS[dev]="$d"
  
  CONFIG_RULES=()
  while IFS= read -r r; do
    [[ -n "$r" ]] && CONFIG_RULES+=("$r")
  done < <(_yaml_get_list "$cf" "rules")
  
  CONFIG_BOUNDARIES=()
  while IFS= read -r b; do
    [[ -n "$b" ]] && CONFIG_BOUNDARIES+=("$b")
  done < <(_yaml_get_list "$cf" "boundaries.never_touch")
  
  if _yaml_get_bool "$cf" "agents.enabled"; then
    CONFIG_AGENTS[enabled]=true
  fi
  if _yaml_get_bool "$cf" "skills.enabled"; then
    CONFIG_SKILLS[enabled]=true
  fi
  if _yaml_get_bool "$cf" "argus.enabled"; then
    CONFIG_ARGUS[enabled]=true
  fi
  if _yaml_get_bool "$cf" "browser.enabled"; then
    CONFIG_BROWSER[enabled]=true
    ENABLE_BROWSER=true
  fi

  # Load browser config values
  local browser_url=$(_yaml_get_value "$cf" "browser.url")
  [[ -n "$browser_url" ]] && CONFIG_BROWSER[url]="$browser_url"

  local browser_headed=$(_yaml_get_value "$cf" "browser.headed")
  [[ -n "$browser_headed" ]] && CONFIG_BROWSER[headed]="$browser_headed"

  local browser_dev=$(_yaml_get_value "$cf" "browser.dev_command")
  [[ -n "$browser_dev" ]] && CONFIG_BROWSER[dev_command]="$browser_dev"

  if _yaml_get_bool "$cf" "quality_gates.enabled"; then
    CONFIG_QUALITY_GATES[enabled]=true
  fi

  CONFIG_LOADED=true
  log_debug "Config loaded"
  return 0
}

# Initialize config with auto-detection
init_config() {
  local cf="$CONFIG_FILE"
  local cd="$CONFIG_DIR"
  
  mkdir -p "$cd"
  
  if [[ -f .gitignore ]] && ! grep -q "^$cd" .gitignore; then
    echo "$cd" >> .gitignore
  fi
  
  [[ -f "$cf" ]] && {
    log_warn "Config exists at $cf"
    return 0
  }
  
  log_info "Auto-detecting project settings..."
  
  local pn lang frm test lint build dev
  eval "$(detect_project_settings)"
  
  pn="${project_name:-$(basename "$(pwd)")}"
  
  log_info "Detected: $language / $framework"
  
  cat > "$cf" << EOFCFG
# Super Ralphy Project Config - $(date +%Y-%m-%d)
project:
  name: "$pn"
  language: "$language"
  framework: "$framework"

commands:
EOFCFG
  
  [[ -n "$test" ]] && echo "  test: $test" >> "$cf"
  [[ -n "$lint" ]] && echo "  lint: $lint" >> "$cf"
  [[ -n "$build" ]] && echo "  build: $build" >> "$cf"
  [[ -n "$dev" ]] && echo "  dev: $dev" >> "$cf"
  
  cat >> "$cf" << EOFCFG2
rules:
  - "follow the existing code style"
  - "write tests for new features"
boundaries:
  never_touch:
    - "node_modules/**"
    - "*.lock"
    - ".env*"
agents:
  enabled: false
skills:
  enabled: false
argus:
  enabled: false
browser:
  enabled: false
  url: "http://localhost:3000"
  headed: false
quality_gates:
  enabled: true
EOFCFG2
  
  [[ -n "$test" ]] && echo "  test: true" >> "$cf" || echo "  test: false" >> "$cf"
  [[ -n "$lint" ]] && echo "  lint: true" >> "$cf" || echo "  lint: false" >> "$cf"
  echo "  typecheck: false" >> "$cf"
  
  log_success "Config created at $cf"
  return 0
}

# Display current config
show_config() {
  echo ""
  echo "Super Ralphy Project Config"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local cf="$CONFIG_FILE"
  if [[ -f "$cf" ]]; then
    echo "Config file: $cf"
    echo ""
    echo "Project:"
    echo "  Name: ${CONFIG_PROJECT[name]:-$(basename "$(pwd)")}"
    echo "  Language: ${CONFIG_PROJECT[language]:-Unknown}"
    echo "  Framework: ${CONFIG_PROJECT[framework]:-Unknown}"
    echo ""
    echo "Commands:"
    echo "  Test: ${CONFIG_COMMANDS[test]:-(none)}"
    echo "  Lint: ${CONFIG_COMMANDS[lint]:-(none)}"
    echo "  Build: ${CONFIG_COMMANDS[build]:-(none)}"
    echo "  Dev: ${CONFIG_COMMANDS[dev]:-(none)}"
    echo ""
    echo "Rules:"
    if [[ ${#CONFIG_RULES[@]} -gt 0 ]]; then
      for r in "${CONFIG_RULES[@]}"; do echo "  - $r"; done
    else
      echo "  (none)"
    fi
  else
    echo "No config file. Run --init to create one."
  fi
  echo ""
}

# Add a rule to config
add_rule() {
  local nr="$1" cf="$CONFIG_FILE"
  [[ -z "$nr" ]] && { log_error "Rule cannot be empty"; return 1; }
  
  [[ -f "$cf" ]] && load_config
  
  for r in "${CONFIG_RULES[@]}"; do
    [[ "$r" == "$nr" ]] && { log_warn "Rule exists: $nr"; return 0; }
  done
  
  mkdir -p "$CONFIG_DIR"
  
  if [[ ! -f "$cf" ]]; then
    cat > "$cf" << EOFCFG3
# Super Ralphy Project Config
project:
  name: "$(basename "$(pwd)")"
rules:
  - "$nr"
agents:
  enabled: false
EOFCFG3
    log_success "Config created with rule"
    return 0
  fi
  
  if command -v yq >/dev/null 2>&1; then
    yq eval ".rules += [\\"$nr\\"]" -i "$cf"
  else
    # Use awk to add the rule after the last rule item (before boundaries:)
    awk -v rule="$nr" '
      /^boundaries:/ {
        print "  - \"" rule "\""
      }
      { print }
    ' "$cf" > "$cf.tmp" && mv "$cf.tmp" "$cf"
  fi
  
  load_config
  log_success "Rule added: $nr"
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Task Parsing with Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_tasks_with_deps() {
  local file="$1"
  local task_id=""
  local task_title=""
  local deps=""
  
  while IFS= read -r line; do
    # Match: - [ ] **TASK-ID**: Description (depends: X, Y)
    # Using simpler grep/sed approach for zsh compatibility
    if echo "$line" | grep -qE '^\s*-\s*\[\s*\]\s*\*\*[A-Z]+-[0-9]+\*\*:'; then
      # Extract TASK-ID
      task_id=$(echo "$line" | sed -nE 's/.*\*\*([A-Z]+-[0-9]+)\*\*:.*/\1/p')
      # Extract description (after the colon, before potential dependency)
      task_title=$(echo "$line" | sed -nE 's/.*\*\*[A-Z]+-[0-9]+\:\*:\s*(.*)(\s*\(depends:|\s*\(after:|\s*$)/\1/p')

      # Extract dependencies
      deps=""
      if echo "$line" | grep -q '(depends:'; then
        deps=$(echo "$line" | sed -nE 's/.*\(depends:\s*([^)]+)\).*/\1/p' | tr ',' ' ' | xargs)
        task_title=$(echo "$task_title" | sed 's/ *(depends: [^)]*)//')
      elif echo "$line" | grep -q '(after:'; then
        deps=$(echo "$line" | sed -nE 's/.*\(after:\s*([^)]+)\).*/\1/p' | tr ',' ' ' | xargs)
        task_title=$(echo "$task_title" | sed 's/ *(after: [^)]*)//')
      fi

      # Clean up
      task_title=$(echo "$task_title" | sed 's/[[:space:]]*$//')
      deps=$(echo "$deps" | tr ',' ' ' | xargs)

      # Store
      TASK_DEPS["$task_id"]="$deps"
      TASK_STATUS["$task_id"]="pending"

      log_debug "Parsed task: $task_id -> $task_title (deps: ${deps:-none})"

      echo "$task_id|$task_title"

    # Also match simpler format: - [ ] Task description
    elif echo "$line" | grep -qE '^\s*-\s*\[\s*\]\s+'; then
      task_title=$(echo "$line" | sed -E 's/^\s*-\s*\[\s*\]\s+(.*)/\1/')

      # Generate ID from title
      task_id=$(echo "$task_title" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/-/g' | cut -c1-20)
      task_id="TASK-$task_id"

      # Extract dependencies
      deps=""
      if echo "$task_title" | grep -q '(depends:'; then
        deps=$(echo "$task_title" | sed -nE 's/.*\(depends:\s*([^)]+)\).*/\1/p' | tr ',' ' ' | xargs)
        task_title=$(echo "$task_title" | sed 's/ *(depends: [^)]*)//')
      fi

      deps=$(echo "$deps" | tr ',' ' ' | xargs)

      TASK_DEPS["$task_id"]="$deps"
      TASK_STATUS["$task_id"]="pending"

      echo "$task_id|$task_title"
    fi
  done < "$file"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# YAML Task Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Parse YAML task file with dependencies and metadata
parse_yaml_tasks() {
  local file="$1"

  # Check if yq is available for proper YAML parsing
  local use_yq=false
  if command -v yq &>/dev/null; then
    use_yq=true
  fi

  if [[ "$use_yq" == true ]]; then
    # Use yq for proper YAML parsing
    parse_yaml_with_yq "$file"
  else
    log_warn "yq not found, using basic YAML parsing (install yq for better support)"
    parse_yaml_basic "$file"
  fi
}

# Parse YAML using yq (preferred method)
parse_yaml_with_yq() {
  local file="$1"
  local task_count=0

  # Get number of tasks
  local count=$(yq eval '.tasks | length' "$file" 2>/dev/null || echo "0")

  if [[ "$count" -eq 0 ]]; then
    log_error "No tasks found in YAML file"
    return 1
  fi

  # First pass: collect all tasks and their groups
  typeset -A GROUP_TASKS  # group -> space-separated task IDs
  typeset -A TITLE_TO_ID  # title -> generated task ID

  for ((i=0; i<count; i++)); do
    local title=$(yq eval ".tasks[$i].title" "$file" 2>/dev/null)
    [[ -z "$title" || "$title" == "null" ]] && continue

    # Generate task ID from title
    local task_id=$(echo "$title" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/-/g' | cut -c1-20)
    task_id="TASK-${task_id}-${i}"

    # Store mapping
    TITLE_TO_ID["$title"]="$task_id"

    # Extract YAML attributes
    local agent=$(yq eval ".tasks[$i].agent // \"\"" "$file" 2>/dev/null)
    local skills=$(yq eval ".tasks[$i].skills[]? // \"\" // \" \"" "$file" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    local verify_browser=$(yq eval ".tasks[$i].verify_browser // \"false\"" "$file" 2>/dev/null)
    local verify_url=$(yq eval ".tasks[$i].verify_url // \"\"" "$file" 2>/dev/null)
    local verify_elements=$(yq eval ".tasks[$i].verify_elements[]? // \"\" // \" \"" "$file" 2>/dev/null | tr '\n' ' ' | xargs)
    local parallel_group=$(yq eval ".tasks[$i].parallel_group // \"0\"" "$file" 2>/dev/null)
    local deps=$(yq eval ".tasks[$i].depends[]? // \"\" // \" \"" "$file" 2>/dev/null | tr '\n' ' ' | xargs)

    # Store YAML-specific attributes
    TASK_AGENT["$task_id"]="$agent"
    TASK_SKILLS["$task_id"]="$skills"
    TASK_VERIFY_BROWSER["$task_id"]="$verify_browser"
    TASK_VERIFY_URL["$task_id"]="$verify_url"
    TASK_VERIFY_ELEMENTS["$task_id"]="$verify_elements"
    TASK_PARALLEL_GROUP["$task_id"]="$parallel_group"
    TASK_RAW_DEPS["$task_id"]="$deps"

    # Track group membership
    if [[ "$parallel_group" != "0" ]]; then
      GROUP_TASKS["$parallel_group"]="${GROUP_TASKS[$parallel_group]:-} $task_id"
    fi

    log_debug "YAML task: $task_id -> $title (group: ${parallel_group:-none}, agent: ${agent:-default})"
  done

  # Second pass: build dependencies from parallel_group and explicit deps
  for ((i=0; i<count; i++)); do
    local title=$(yq eval ".tasks[$i].title" "$file" 2>/dev/null)
    [[ -z "$title" || "$title" == "null" ]] && continue

    local task_id="${TITLE_TO_ID[$title]}"
    local parallel_group=$(yq eval ".tasks[$i].parallel_group // \"0\"" "$file" 2>/dev/null)
    local deps=$(yq eval ".tasks[$i].depends[]? // \"\" // \" \"" "$file" 2>/dev/null | tr '\n' ' ' | xargs)

    # Build dependency list
    local final_deps=""

    # Add explicit dependencies
    if [[ -n "$deps" ]]; then
      # Resolve dependency titles to IDs
      for dep_title in $deps; do
        local dep_id="${TITLE_TO_ID[$dep_title]:-}"
        if [[ -n "$dep_id" ]]; then
          final_deps="$final_deps $dep_id"
        else
          # Try direct task ID reference
          final_deps="$final_deps $dep_title"
        fi
      done
    fi

    # Add parallel_group dependencies (tasks in group N depend on group N-1)
    if [[ "$parallel_group" != "0" ]]; then
      local prev_group=$((parallel_group - 1))
      if [[ -n "${GROUP_TASKS[$prev_group]:-}" ]]; then
        for prev_task in ${GROUP_TASKS[$prev_group]}; do
          # Avoid duplicates
          if [[ ! " $final_deps " =~ " $prev_task " ]]; then
            final_deps="$final_deps $prev_task"
          fi
        done
      fi
    fi

    # Clean up and store
    final_deps=$(echo "$final_deps" | xargs)
    TASK_DEPS["$task_id"]="$final_deps"
    TASK_STATUS["$task_id"]="pending"

    # Output for compatibility with existing parser
    echo "$task_id|$title"

    ((task_count++))
  done

  log_info "Parsed $task_count tasks from YAML (using yq)"
}

# Basic YAML parsing without yq (fallback)
parse_yaml_basic() {
  local file="$1"
  local in_tasks=false
  local task_count=0

  # Task data accumulators
  local _current_title=""
  local _current_agent=""
  local _current_skills=""
  local _current_verify_browser="false"
  local _current_verify_url=""
  local _current_verify_elements=""
  local _current_parallel_group="0"
  local _current_deps=""
  local current_task_id=""

  local line_num=0

  while IFS= read -r line; do
    ((line_num++))

    # Trim leading/trailing whitespace (using sed for reliable space handling)
    local trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Check for tasks: entry
    if [[ "$trimmed" =~ ^tasks: ]]; then
      in_tasks=true
      continue
    fi

    if [[ "$in_tasks" == true ]]; then
      # New task entry starts with dash (either alone or with inline key:value)
      if [[ "$trimmed" =~ ^-[[:space:]]*([a-z_]+):[[:space:]]*(.*)$ ]]; then
        # Inline format: - title: something
        # Save previous task if exists
        if [[ -n "$current_task_id" ]]; then
          _finalize_yaml_task "$current_task_id" "$_current_title" "$_current_agent" "$_current_skills" "$_current_verify_browser" "$_current_verify_url" "$_current_verify_elements" "$_current_parallel_group" "$_current_deps"
        fi
        # Reset accumulators
        _current_title=""
        _current_agent=""
        _current_skills=""
        _current_verify_browser="false"
        _current_verify_url=""
        _current_verify_elements=""
        _current_parallel_group="0"
        _current_deps=""
        ((task_count++))

        # Process the inline key:value
        local key="${match[1]}"
        local value="${match[2]}"
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"

        case "$key" in
          title)
            _current_title="$value"
            current_task_id=$(echo "$_current_title" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/-/g' | cut -c1-20)
            current_task_id="TASK-${current_task_id}-${task_count}"
            ;;
          agent) _current_agent="$value" ;;
          skills) _current_skills=$(echo "$value" | sed 's/[,[:space:]]/ /g' | xargs) ;;
          verify_browser) _current_verify_browser="$value" ;;
          verify_url) _current_verify_url="$value" ;;
          verify_elements) _current_verify_elements=$(echo "$value" | sed 's/[,[:space:]]/ /g' | xargs) ;;
          parallel_group) _current_parallel_group="$value" ;;
          depends) _current_deps=$(echo "$value" | sed 's/[,[:space:]]/ /g' | xargs) ;;
        esac
        continue
      fi

      # Standalone dash followed by key:value on next line
      if [[ "$trimmed" =~ ^-[[:space:]]*$ ]]; then
        # Save previous task if exists
        if [[ -n "$current_task_id" ]]; then
          _finalize_yaml_task "$current_task_id" "$_current_title" "$_current_agent" "$_current_skills" "$_current_verify_browser" "$_current_verify_url" "$_current_verify_elements" "$_current_parallel_group" "$_current_deps"
        fi
        # Reset accumulators
        _current_title=""
        _current_agent=""
        _current_skills=""
        _current_verify_browser="false"
        _current_verify_url=""
        _current_verify_elements=""
        _current_parallel_group="0"
        _current_deps=""
        ((task_count++))
        continue
      fi

      # Extract key: value pairs (trimmed line, so no leading space)
      # Use case statement for cleaner matching
      case "$trimmed" in
        title:*)
          _current_title="${trimmed#title: }"
          _current_title="${_current_title#\"}"; _current_title="${_current_title%\"}"
          _current_title="${_current_title#\'}"; _current_title="${_current_title%\'}"

          # Generate task ID
          current_task_id=$(echo "$_current_title" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/-/g' | cut -c1-20)
          current_task_id="TASK-${current_task_id}-${task_count}"
          ;;
        agent:*)
          _current_agent="${trimmed#agent: }"
          ;;
        verify_browser:*)
          _current_verify_browser="${trimmed#verify_browser: }"
          ;;
        verify_url:*)
          _current_verify_url="${trimmed#verify_url: }"
          _current_verify_url="${_current_verify_url#\"}"; _current_verify_url="${_current_verify_url%\"}"
          ;;
        parallel_group:*)
          _current_parallel_group="${trimmed#parallel_group: }"
          ;;
      esac

      # Special handling for skills and depends (need bracket detection)
      if [[ "$trimmed" == skills:\ * ]]; then
        # Check if it has brackets
        if [[ "$trimmed" =~ "\[(.+)\]" ]]; then
          _current_skills=$(echo "$match[1]" | sed 's/[,[:space:]]/ /g' | xargs)
        else
          _current_skills="${trimmed#skills: }"
          _current_skills="${_current_skills#\"}"; _current_skills="${_current_skills%\"}"
        fi
      fi

      if [[ "$trimmed" == depends:\ * ]]; then
        # Check if it has brackets
        if [[ "$trimmed" =~ "\[(.+)\]" ]]; then
          _current_deps=$(echo "$match[1]" | sed 's/[,[:space:]]/ /g' | xargs)
        fi
      fi

      # End of task (blank line or new section)
      if [[ -z "$trimmed" ]] && [[ -n "$current_task_id" ]]; then
        _finalize_yaml_task "$current_task_id" "$_current_title" "$_current_agent" "$_current_skills" "$_current_verify_browser" "$_current_verify_url" "$_current_verify_elements" "$_current_parallel_group" "$_current_deps"
        current_task_id=""
        _current_title=""
        _current_agent=""
        _current_skills=""
        _current_verify_browser="false"
        _current_verify_url=""
        _current_verify_elements=""
        _current_parallel_group="0"
        _current_deps=""
      fi
    fi

  done < "$file"

  # Save last task
  if [[ -n "$current_task_id" ]]; then
    _finalize_yaml_task "$current_task_id" "$_current_title" "$_current_agent" "$_current_skills" "$_current_verify_browser" "$_current_verify_url" "$_current_verify_elements" "$_current_parallel_group" "$_current_deps"
  fi

  log_info "Parsed $task_count tasks from YAML (basic parser)"
}

# Finalize a parsed YAML task entry (internal helper)
# Note: In zsh, we use global variables for the associative arrays
_finalize_yaml_task() {
  local task_id="$1"
  local title="$2"
  local agent="$3"
  local skills="$4"
  local verify_browser="$5"
  local verify_url="$6"
  local verify_elements="$7"
  local parallel_group="$8"
  local deps="$9"

  # Store YAML-specific attributes
  TASK_AGENT["$task_id"]="$agent"
  TASK_SKILLS["$task_id"]="$skills"
  TASK_VERIFY_BROWSER["$task_id"]="$verify_browser"
  TASK_VERIFY_URL["$task_id"]="$verify_url"
  TASK_VERIFY_ELEMENTS["$task_id"]="$verify_elements"
  TASK_PARALLEL_GROUP["$task_id"]="$parallel_group"
  TASK_RAW_DEPS["$task_id"]="$deps"

  # Track group membership globally
  if [[ "$parallel_group" != "0" ]]; then
    _YAML_GROUP_TASKS["$parallel_group"]="${_YAML_GROUP_TASKS[$parallel_group]:-} $task_id"
  fi

  # Build dependencies from parallel_group
  local final_deps="$deps"
  if [[ "$parallel_group" != "0" ]]; then
    local prev_group=$((parallel_group - 1))
    local prev_tasks="${_YAML_GROUP_TASKS[$prev_group]:-}"
    if [[ -n "$prev_tasks" ]]; then
      # Split on whitespace and add each task as a dependency
      for prev_task in ${(z)prev_tasks}; do
        if [[ ! " $final_deps " =~ " $prev_task " ]]; then
          final_deps="$final_deps $prev_task"
        fi
      done
    fi
  fi

  final_deps=$(echo "$final_deps" | xargs)
  TASK_DEPS["$task_id"]="$final_deps"
  TASK_STATUS["$task_id"]="pending"

  log_debug "YAML task: $task_id -> $title (group: ${parallel_group:-none}, agent: ${agent:-default})"

  # Output for compatibility
  echo "$task_id|$title"
}

# Dependency Graph & Topological Sort
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if all dependencies of a task are done
deps_satisfied() {
  local task="$1"
  local deps="${TASK_DEPS[$task]:-}"
  
  [[ -z "$deps" ]] && return 0
  
  for dep in $deps; do
    if [[ "${TASK_STATUS[$dep]:-}" != "done" ]]; then
      return 1
    fi
  done
  
  return 0
}

# Get tasks that are ready to run (deps satisfied, not running/done)
get_ready_tasks() {
  for task in "${(k)TASK_STATUS}"; do
    if [[ "${TASK_STATUS[$task]}" == "pending" ]] && deps_satisfied "$task"; then
      echo "$task"
    fi
  done
}

# Count tasks by status
count_by_status() {
  local status="$1"
  local count=0
  for task in "${(k)TASK_STATUS}"; do
    [[ "${TASK_STATUS[$task]}" == "$status" ]] && ((count++))
  done
  echo "$count"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Git Worktree Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_worktree_dir() {
  mkdir -p "$WORKTREE_DIR"
  
  # Add to gitignore if not there
  if [[ -f .gitignore ]] && ! grep -q "^$WORKTREE_DIR" .gitignore; then
    echo "$WORKTREE_DIR" >> .gitignore
    log_debug "Added $WORKTREE_DIR to .gitignore"
  fi
}

create_worktree() {
  local task="$1"
  local branch="super-ralphy/$task"
  local worktree_path="$WORKTREE_DIR/$task"
  
  # Get current branch as base
  local base="${BASE_BRANCH:-$(git branch --show-current)}"
  
  log_worktree "Creating worktree for $task"
  
  # Create branch and worktree
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git branch -D "$branch" 2>/dev/null || true
  fi
  
  # Remove existing worktree if exists
  if [[ -d "$worktree_path" ]]; then
    git worktree remove "$worktree_path" --force 2>/dev/null || true
    rm -rf "$worktree_path" 2>/dev/null || true
  fi
  
  # Create new worktree with branch
  git worktree add -b "$branch" "$worktree_path" "$base" 2>/dev/null || {
    log_error "Failed to create worktree for $task"
    return 1
  }
  
  TASK_BRANCH["$task"]="$branch"
  TASK_WORKTREE["$task"]="$worktree_path"
  
  log_success "Created worktree: $worktree_path (branch: $branch)"
  return 0
}

cleanup_worktree() {
  local task="$1"
  local worktree_path="${TASK_WORKTREE[$task]:-}"
  
  if [[ -n "$worktree_path" && -d "$worktree_path" ]]; then
    log_worktree "Cleaning up worktree for $task"
    git worktree remove "$worktree_path" --force 2>/dev/null || true
    rm -rf "$worktree_path" 2>/dev/null || true
  fi
}

cleanup_all_worktrees() {
  log_info "Cleaning up all worktrees..."
  
  for task in "${(k)TASK_WORKTREE}"; do
    cleanup_worktree "$task"
  done
  
  # Prune stale worktrees
  git worktree prune 2>/dev/null || true
  
  # Remove worktree directory if empty
  rmdir "$WORKTREE_DIR" 2>/dev/null || true
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Skills & Agent Prompt Building
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_skills() {
  local task="$1"
  local task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')
  local skills=()

  [[ "$task_lower" =~ "(convex|mutation|query|schema)" ]] && skills+=("convex")
  [[ "$task_lower" =~ "(next|page|component|react)" ]] && skills+=("nextjs")
  [[ "$task_lower" =~ "(test|spec|coverage)" ]] && skills+=("testing")
  [[ "$task_lower" =~ "(typescript|type|interface)" ]] && skills+=("typescript")

  echo "${skills[*]}"
}

load_skills() {
  local skills="$1"
  local content=""
  
  for skill in $skills; do
    local skill_file="$SKILLS_DIR/$skill/SKILL.md"
    if [[ -f "$skill_file" ]]; then
      content+="
--- SKILL: $skill ---
$(cat "$skill_file")
"
    fi
  done
  
  echo "$content"
}

# Detect agent type from task title keywords
detect_agent_type() {
  local task_title="$1"
  local task_lower=$(echo "$task_title" | tr '[:upper:]' '[:lower:]')

  # Check keywords in order of priority (most specific first)
  if [[ "$task_lower" =~ "test" ]] || \
     [[ "$task_lower" =~ "spec" ]] || \
     [[ "$task_lower" =~ "coverage" ]] || \
     [[ "$task_lower" =~ "pytest" ]] || \
     [[ "$task_lower" =~ "jest" ]] || \
     [[ "$task_lower" =~ "vitest" ]]; then
    echo "tester"
    return 0
  fi

  if [[ "$task_lower" =~ "review" ]] || \
     [[ "$task_lower" =~ "audit" ]] || \
     [[ "$task_lower" =~ "verify" ]] || \
     [[ "$task_lower" =~ "security" ]] || \
     [[ "$task_lower" =~ "inspect" ]] || \
     [[ "$task_lower" =~ "check" ]]; then
    echo "reviewer"
    return 0
  fi

  if [[ "$task_lower" =~ "document" ]] || \
     [[ "$task_lower" =~ "readme" ]] || \
     [[ "$task_lower" =~ "docs" ]] || \
     [[ "$task_lower" =~ "comment" ]] || \
     [[ "$task_lower" =~ "api doc" ]]; then
    echo "documenter"
    return 0
  fi

  if [[ "$task_lower" =~ "browser" ]] || \
     [[ "$task_lower" =~ "ui" ]] || \
     [[ "$task_lower" =~ "visual" ]] || \
     [[ "$task_lower" =~ "frontend" ]] || \
     [[ "$task_lower" =~ "interface" ]] || \
     [[ "$task_lower" =~ "design" ]]; then
    echo "browser"
    return 0
  fi

  # Default to coder
  echo "coder"
  return 0
}

# Load custom agent instructions from .claude/agents/{agent}/AGENT.md
load_agent_instructions() {
  local agent_type="$1"
  local agent_file="$AGENTS_DIR/$agent_type/AGENT.md"

  if [[ -f "$agent_file" ]]; then
    log_debug "Loading custom instructions for agent: $agent_type"
    cat "$agent_file"
  fi
}

# Get agent-specific prompt template
get_agent_prompt() {
  local agent_type="$1"
  local task_title="$2"

  case "$agent_type" in
    tester)
      echo "You are a TESTING SPECIALIST. Your focus is writing comprehensive, reliable tests.

TASK: $task_title

Write thorough tests using testing best practices:
- Cover happy path and edge cases
- Test error conditions and boundary values
- Use descriptive test names
- Follow the project's testing conventions
- Aim for high coverage of meaningful cases

When done, commit with message: test: \$task_title [\$TASK_ID]"
      ;;

    reviewer)
      echo "You are a CODE REVIEWER. Your focus is quality, security, and maintainability.

TASK: $task_title

Review for:
- Security vulnerabilities and potential exploits
- Performance issues and inefficiencies
- Code smell and maintainability concerns
- Edge cases and error handling
- Adherence to project conventions

Provide specific, actionable feedback.
When done, commit with message: review: \$task_title [\$TASK_ID]"
      ;;

    documenter)
      echo "You are a DOCUMENTATION SPECIALIST. Your focus is clear, comprehensive documentation.

TASK: $task_title

Write documentation that is:
- Clear and concise
- Includes examples where helpful
- Covers usage and API surface
- Explains 'why' not just 'what'
- Uses consistent formatting

When done, commit with message: docs: \$task_title [\$TASK_ID]"
      ;;

    browser)
      echo "You are a BROWSER/UI SPECIALIST. Your focus is visual correctness and user experience.

TASK: $task_title

Ensure the UI:
- Looks correct across viewport sizes
- Has proper spacing and alignment
- Includes appropriate hover/active states
- Is accessible (keyboard navigation, aria labels)
- Matches the design specifications

Test interactively when possible.
When done, commit with message: ui: \$task_title [\$TASK_ID]"
      ;;

    coder|*)
      echo "You are an IMPLEMENTATION SPECIALIST. Your focus is clean, working code.

TASK: $task_title

Complete this task:
- Write clean, idiomatic code
- Follow existing project conventions
- Handle errors appropriately
- Keep changes focused and minimal
- Write tests for new functionality

When done, commit with message: feat: \$task_title [\$TASK_ID]"
      ;;
  esac
}

build_prompt() {
  local task_id="$1"
  local task_title="$2"
  local prompt=""

  # Determine agent type if enabled
  local agent_type="coder"
  if [[ "$ENABLE_AGENTS" == true ]]; then
    # Check if task has a pre-specified agent (from YAML)
    if [[ -n "${TASK_AGENT[$task_id]:-}" ]]; then
      agent_type="${TASK_AGENT[$task_id]}"
    else
      agent_type=$(detect_agent_type "$task_title")
    fi
    log_debug "Task $task_id assigned to agent: $agent_type"
  fi

  # Load custom agent instructions if they exist
  if [[ "$ENABLE_AGENTS" == true ]]; then
    local custom_instructions=$(load_agent_instructions "$agent_type")
    if [[ -n "$custom_instructions" ]]; then
      prompt+="--- CUSTOM AGENT INSTRUCTIONS ---
$custom_instructions

"
    fi
  fi

  # Skills injection
  if [[ "$ENABLE_SKILLS" == true ]]; then
    local skills=$(detect_skills "$task_title")
    if [[ -n "$skills" ]]; then
      prompt+="$(load_skills "$skills")

"
    fi
  fi

  # Use agent-specific prompt or default
  if [[ "$ENABLE_AGENTS" == true ]]; then
    local agent_prompt=$(get_agent_prompt "$agent_type" "$task_title")
    # Replace variables in agent prompt
    agent_prompt="${agent_prompt//\$TASK_ID/$task_id}"
    agent_prompt="${agent_prompt//\$task_title/$task_title}"
    prompt+="$agent_prompt"
  else
    prompt+="TASK: $task_title

Complete this task. Keep changes focused and minimal.
When done, commit with message: feat: $task_title [$task_id]"
  fi

  echo "$prompt"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Task Execution
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

execute_task_in_worktree() {
  local task_id="$1"
  local task_title="$2"
  local worktree="${TASK_WORKTREE[$task_id]}"
  local log_file="$WORKTREE_DIR/$task_id.log"
  
  log_parallel "[$task_id] Starting in $worktree"
  
  local prompt=$(build_prompt "$task_id" "$task_title")
  
  # Run Claude in the worktree
  (
    cd "$worktree"
    
    # Argus refresh in worktree
    if [[ "$ENABLE_ARGUS" == true ]] && command -v argus &>/dev/null; then
      argus snapshot . -o .argus/snapshot.txt --enhanced 2>/dev/null || true
    fi
    
    # Execute with Claude
    if claude -p "$prompt" --dangerously-skip-permissions &> "$log_file"; then
      # Auto-commit
      if [[ "$NO_COMMIT" != true ]]; then
        git add -A
        git commit -m "feat: $task_title [$task_id]" 2>/dev/null || true
      fi
      exit 0
    else
      exit 1
    fi
  )
  
  return $?
}

# Execute task in background, store PID
launch_task() {
  local task_id="$1"
  local task_title="$2"

  TASK_STATUS["$task_id"]="running"
  write_task_note "$task_id" "started" "$task_title"

  if [[ "$USE_WORKTREES" == true ]]; then
    create_worktree "$task_id" || {
      TASK_STATUS["$task_id"]="failed"
      write_task_note "$task_id" "failed" "$task_title (worktree creation failed)"
      return 1
    }

    # Run in background
    execute_task_in_worktree "$task_id" "$task_title" &
    TASK_PID["$task_id"]=$!
    ((RUNNING_COUNT++))

    log_parallel "[$task_id] Launched (PID: ${TASK_PID[$task_id]})"
  else
    # Sequential in main dir
    execute_task_in_worktree "$task_id" "$task_title"
    if [[ $? -eq 0 ]]; then
      TASK_STATUS["$task_id"]="done"
      write_task_note "$task_id" "completed" "$task_title"
    else
      TASK_STATUS["$task_id"]="failed"
      write_task_note "$task_id" "failed" "$task_title"
    fi
  fi
}

# Check if a running task has completed
check_task_completion() {
  local task_id="$1"
  local pid="${TASK_PID[$task_id]:-}"

  [[ -z "$pid" ]] && return 1

  if ! kill -0 "$pid" 2>/dev/null; then
    # Process finished, check exit status
    wait "$pid" 2>/dev/null
    local exit_code=$?

    ((RUNNING_COUNT--))

    if [[ $exit_code -eq 0 ]]; then
      TASK_STATUS["$task_id"]="done"
      log_success "[$task_id] Completed"
      write_task_note "$task_id" "completed" "Task completed"

      # Run browser verification if enabled and task has verify_browser set
      if [[ "$ENABLE_BROWSER" == true ]] || [[ "${TASK_VERIFY_BROWSER[$task_id]:-false}" == "true" ]]; then
        local verify_url="${TASK_VERIFY_URL[$task_id]:-}"
        local verify_elements="${TASK_VERIFY_ELEMENTS[$task_id]:-}"
        local task_title="${TASK_TITLES[$task_id]:-$task_id}"
        verify_browser "$task_id" "$task_title" "$verify_url" "$verify_elements" || true
      fi

      return 0
    else
      TASK_STATUS["$task_id"]="failed"
      log_error "[$task_id] Failed (see $WORKTREE_DIR/$task_id.log)"
      write_task_note "$task_id" "failed" "Task failed (see logs)"
      return 1
    fi
  fi

  return 2  # Still running
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Branch Merging
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

merge_branch() {
  local task_id="$1"
  local branch="${TASK_BRANCH[$task_id]}"
  local base="${BASE_BRANCH:-$(git branch --show-current)}"

  write_task_note "$task_id" "merging" "Merging $branch into $base"
  log_merge "Merging $branch into $base"

  # Try regular merge first
  if git merge "$branch" -m "Merge $task_id: $(git log -1 --format=%s $branch)" 2>/dev/null; then
    log_success "Merged $task_id cleanly"
    write_task_note "$task_id" "merged" "Clean merge"
    return 0
  fi

  # Merge conflict - try AI resolution
  if [[ "$AI_MERGE" == true ]]; then
    log_merge "Conflict detected, using AI to resolve..."

    local conflicts=$(git diff --name-only --diff-filter=U)

    for file in $conflicts; do
      log_merge "Resolving: $file"

      # Get conflict content
      local conflict_content=$(cat "$file")

      # Use Claude to resolve
      local resolution=$(claude -p "Resolve this git merge conflict intelligently. Output ONLY the resolved file content, no explanations:

$conflict_content" --dangerously-skip-permissions 2>/dev/null)

      if [[ -n "$resolution" ]]; then
        echo "$resolution" > "$file"
        git add "$file"
      else
        log_warn "AI couldn't resolve $file, leaving conflict markers"
        write_task_note "$task_id" "merge_failed" "AI conflict resolution failed"
        return 1
      fi
    done

    git commit -m "Merge $task_id with AI conflict resolution" 2>/dev/null
    log_success "Merged $task_id with AI resolution"
    write_task_note "$task_id" "merged" "AI conflict resolution"
    return 0
  else
    log_error "Merge conflict in $task_id - manual resolution needed"
    write_task_note "$task_id" "merge_failed" "Manual resolution needed"
    git merge --abort 2>/dev/null || true
    return 1
  fi
}

merge_completed_tasks() {
  log_info "Merging completed branches..."
  
  local merged=0
  local failed=0
  
  for task_id in "${(k)TASK_STATUS}"; do
    if [[ "${TASK_STATUS[$task_id]}" == "done" && -n "${TASK_BRANCH[$task_id]:-}" ]]; then
      if merge_branch "$task_id"; then
        ((merged++))
        cleanup_worktree "$task_id"
        
        # Delete branch after merge
        git branch -d "${TASK_BRANCH[$task_id]}" 2>/dev/null || true
      else
        ((failed++))
      fi
    fi
  done
  
  log_info "Merged $merged branches ($failed conflicts)"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argus Integration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

refresh_argus() {
  if command -v argus &>/dev/null; then
    log_info "Refreshing Argus snapshot..."
    argus snapshot . -o .argus/snapshot.txt --enhanced 2>/dev/null && \
      log_success "Argus snapshot refreshed (with metadata)"
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Working Notes
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

init_working_notes() {
  [[ "$ENABLE_NOTES" != true ]] && return 0

  # Create notes directory
  mkdir -p "$NOTES_DIR"

  # Generate session file with timestamp
  SESSION_START_TIME=$(date +%Y-%m-%d-%H%M%S)
  SESSION_FILE="$NOTES_DIR/session-$SESSION_START_TIME.md"

  # Get current git branch and commit
  local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
  local current_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

  # Build configuration string
  local config=""
  [[ "$PARALLEL" == true ]] && config="${config} --parallel"
  [[ "$MAX_PARALLEL" != "3" ]] && config="${config} --max-parallel $MAX_PARALLEL"
  [[ "$ENABLE_AGENTS" == true ]] && config="${config} --agents"
  [[ "$ENABLE_SKILLS" == true ]] && config="${config} --skills"
  [[ "$ENABLE_ARGUS" == true ]] && config="${config} --argus"
  [[ "$ENABLE_BROWSER" == true ]] && config="${config} --browser"
  [[ "$ENABLE_QUALITY_GATES" == true ]] && config="${config} --quality-gates"
  [[ "$AI_MERGE" == false ]] && config="${config} --no-ai-merge"
  [[ "$NO_COMMIT" == true ]] && config="${config} --no-commit"
  [[ "$STRICT_MODE" == true ]] && config="${config} --strict"
  [[ "$DRY_RUN" == true ]] && config="${config} --dry-run"

  # Write session header
  cat > "$SESSION_FILE" << EOF
# Super Ralphy Working Notes
**Session**: $SESSION_START_TIME
**Branch**: $current_branch
**Commit**: $current_commit

## Configuration
$config

## Tasks
EOF

  log_debug "Working notes: $SESSION_FILE"
  write_working_note "Session started"
}

write_working_note() {
  [[ "$ENABLE_NOTES" != true ]] && return 0
  [[ -z "$SESSION_FILE" ]] && return 0

  local timestamp=$(date +%H:%M:%S)
  local message="$1"

  echo "- [$timestamp] $message" >> "$SESSION_FILE"
}

write_task_note() {
  [[ "$ENABLE_NOTES" != true ]] && return 0
  [[ -z "$SESSION_FILE" ]] && return 0

  local task_id="$1"
  local status="$2"
  local task_title="$3"

  local timestamp=$(date +%H:%M:%S)
  local status_icon=""

  case "$status" in
    started) status_icon="▶" ;;
    completed) status_icon="✓" ;;
    failed) status_icon="✗" ;;
    merging) status_icon="⚡" ;;
    *) status_icon="•" ;;
  esac

  echo "- [$timestamp] [$status_icon] **$task_id**: $task_title ($status)" >> "$SESSION_FILE"
}

write_session_summary() {
  [[ "$ENABLE_NOTES" != true ]] && return 0
  [[ -z "$SESSION_FILE" ]] && return 0

  local done=$(count_by_status "done")
  local failed=$(count_by_status "failed")
  local total=${#TASK_STATUS[@]}

  local end_time=$(date +%H:%M:%S)

  cat >> "$SESSION_FILE" << EOF

## Summary
**End Time**: $end_time
**Completed**: $done
**Failed**: $failed
**Total**: $total

---
EOF

  log_debug "Session notes written to: $SESSION_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Quality Gates
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get command from config or use default
get_gate_command() {
  local gate_type="$1"
  local default_cmd="$2"

  # Check YAML config first
  if [[ -f "$CONFIG_FILE" ]]; then
    # Simple grep-based YAML extraction (avoiding yq dependency)
    local key="quality_gates.${gate_type}"
    local cmd=$(grep -E "^${key}:" "$CONFIG_FILE" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//')
    if [[ -n "$cmd" && "$cmd" != "null" ]]; then
      echo "$cmd"
      return
    fi
  fi

  echo "$default_cmd"
}

# Run a single quality gate with retry logic
run_single_gate() {
  local gate_name="$1"
  local gate_cmd="$2"
  local retry_count=0
  local max_retries="$MAX_RETRIES"

  while [[ $retry_count -lt $max_retries ]]; do
    log_info "Running $gate_name gate (attempt $((retry_count + 1))/$max_retries)..."

    if eval "$gate_cmd" 2>&1; then
      log_success "$gate_name gate passed"
      return 0
    else
      local exit_code=$?
      log_error "$gate_name gate failed (exit code: $exit_code)"

      ((retry_count++))

      if [[ $retry_count -lt $max_retries ]]; then
        log_warn "Attempting to fix $gate_name issues with Claude..."

        local fix_prompt="The following quality gate failed:
Gate: $gate_name
Command: $gate_cmd

Please fix the issues that caused this gate to fail. Make minimal changes to address the failures."

        if claude -p "$fix_prompt" --dangerously-skip-permissions 2>/dev/null; then
          log_info "Applied fix attempt, retrying $gate_name gate..."

          # Commit the fix if enabled
          if [[ "$NO_COMMIT" != true ]]; then
            git add -A 2>/dev/null || true
            git commit -m "fix: auto-fix $gate_name gate failures" 2>/dev/null || true
          fi
        else
          log_warn "Claude couldn't fix the issues"
        fi
      else
        log_error "$gate_name gate failed after $max_retries attempts"
        return 1
      fi
    fi
  done

  return 1
}

# Run all enabled quality gates
run_quality_gates() {
  [[ "$ENABLE_QUALITY_GATES" != true ]] && return 0

  log_info "Running quality gates..."

  local gates_passed=0
  local gates_failed=0
  local has_gates=false

  # Test gate
  if [[ "$GATE_TEST" == true ]]; then
    has_gates=true
    local test_cmd=$(get_gate_command "test" "npm test")
    if run_single_gate "test" "$test_cmd"; then
      ((gates_passed++))
    else
      ((gates_failed++))
    fi
  fi

  # Lint gate
  if [[ "$GATE_LINT" == true ]]; then
    has_gates=true
    local lint_cmd=$(get_gate_command "lint" "npm run lint")
    if run_single_gate "lint" "$lint_cmd"; then
      ((gates_passed++))
    else
      ((gates_failed++))
    fi
  fi

  # Typecheck gate
  if [[ "$GATE_TYPECHECK" == true ]]; then
    has_gates=true
    local typecheck_cmd=$(get_gate_command "typecheck" "npm run typecheck")
    if run_single_gate "typecheck" "$typecheck_cmd"; then
      ((gates_passed++))
    else
      ((gates_failed++))
    fi
  fi

  if [[ "$has_gates" == true ]]; then
    if [[ $gates_failed -eq 0 ]]; then
      log_success "All quality gates passed ($gates_passed/$gates_passed)"
      return 0
    else
      log_error "Quality gates: $gates_passed passed, $gates_failed failed"

      if [[ "$STRICT_MODE" == true ]]; then
        return 1
      fi
    fi
  fi

  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Browser Verification (agent-browser)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if agent-browser is installed and available
check_agent_browser() {
  if ! command -v agent-browser &>/dev/null; then
    log_warn "agent-browser not found. Install with: npm install -g agent-browser"
    return 1
  fi
  return 0
}

# Auto-detect dev server command from project
detect_dev_command() {
  # Check config first
  if [[ -n "${CONFIG_COMMANDS[dev]:-}" ]]; then
    echo "${CONFIG_COMMANDS[dev]}"
    return 0
  fi

  # Auto-detect based on project files
  if [[ -f package.json ]]; then
    local dev_cmd=$(jq -r '.scripts.dev // .scripts.develop // empty' package.json 2>/dev/null)
    if [[ -n "$dev_cmd" ]]; then
      echo "npm run dev"
      return 0
    fi
  elif [[ -f pyproject.toml ]] || [[ -f requirements.txt ]]; then
    if [[ -f manage.py ]]; then
      echo "python manage.py runserver"
      return 0
    fi
    echo "python -m http.server 8000"
    return 0
  elif [[ -f go.mod ]]; then
    echo "go run ."
    return 0
  elif [[ -f Cargo.toml ]]; then
    echo "cargo run"
    return 0
  fi

  # Default fallback
  echo "npm run dev"
  return 0
}

# Start dev server in background
start_dev_server() {
  local task_id="$1"
  local dev_cmd="${BROWSER_DEV_COMMAND:-$(detect_dev_command)}"

  log_browser "Starting dev server: $dev_cmd"

  # Create log file for dev server
  local dev_log="$WORKTREE_DIR/dev-server-$task_id.log"

  # Start dev server in background
  cd "$WORKTREE_DIR/${TASK_WORKTREE[$task_id]:-.}" 2>/dev/null || cd .

  # Run dev server and capture PID
  eval "$dev_cmd" > "$dev_log" 2>&1 &
  local pid=$!

  DEV_SERVER_PIDS["$task_id"]=$pid

  log_debug "Dev server started with PID: $pid"

  # Wait for server to start (give it up to 10 seconds)
  local wait_count=0
  while [[ $wait_count -lt 10 ]]; do
    if kill -0 "$pid" 2>/dev/null; then
      # Server process is running, give it a moment more to be ready
      sleep 2
      log_success "Dev server is running (PID: $pid)"
      return 0
    fi
    sleep 1
    ((wait_count++))
  done

  log_warn "Dev server may not have started properly (check $dev_log)"
  return 1
}

# Stop dev server for a task
stop_dev_server() {
  local task_id="$1"
  local pid="${DEV_SERVER_PIDS[$task_id]:-}"

  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    log_browser "Stopping dev server (PID: $pid)"
    kill "$pid" 2>/dev/null || true
    # Also kill any child processes
    pkill -P "$pid" 2>/dev/null || true
    unset "DEV_SERVER_PIDS[$task_id]"
  fi
}

# Stop all dev servers
stop_all_dev_servers() {
  log_debug "Stopping all dev servers..."
  for task_id in "${(k)DEV_SERVER_PIDS}"; do
    stop_dev_server "$task_id"
  done
}

# Take a screenshot using agent-browser
take_browser_screenshot() {
  local browser_id="$1"
  local output_path="$2"

  if ! check_agent_browser; then
    return 1
  fi

  log_browser "Taking screenshot: $output_path"

  # Create screenshots directory
  mkdir -p "$(dirname "$output_path")"

  # Take screenshot
  if agent-browser screenshot "$browser_id" "$output_path" 2>/dev/null; then
    log_success "Screenshot saved: $output_path"
    return 0
  else
    log_warn "Screenshot failed"
    return 1
  fi
}

# Verify elements in browser snapshot
verify_elements_in_snapshot() {
  local snapshot="$1"
  local elements="$2"  # Space-separated list of CSS selectors

  local found=0
  local missing=0
  local results=()

  for element in $elements; do
    # Check if element exists in snapshot
    # agent-browser snapshot output includes element references
    if echo "$snapshot" | grep -qi "$element"; then
      ((found++))
      results+=("  ${GREEN}✓${RESET} $element")
    else
      ((missing++))
      results+=("  ${RED}✗${RESET} $element (not found)")
    fi
  done

  # Print results
  for result in "${results[@]}"; do
    log_browser "$result"
  done

  log_browser "Elements found: $found, missing: $missing"

  # Return success if all elements found
  [[ $missing -eq 0 ]] && return 0 || return 1
}

# Main browser verification function
verify_browser() {
  local task_id="$1"
  local task_title="$2"
  local url="${3:-$BROWSER_URL}"
  local elements="${4:-}"  # Optional space-separated CSS selectors

  if ! check_agent_browser; then
    log_warn "Skipping browser verification (agent-browser not installed)"
    return 0  # Don't fail the task, just skip
  fi

  log_browser "Verifying task: $task_id"
  log_browser "URL: $url"

  # Build full URL (handle relative paths)
  local full_url="$url"
  if [[ ! "$url" =~ ^https?:// ]]; then
    full_url="${BROWSER_URL}${url}"
  fi
  log_browser "Full URL: $full_url"

  # Start dev server if not already running
  local server_pid="${DEV_SERVER_PIDS[$task_id]:-}"
  if [[ -z "$server_pid" ]] || ! kill -0 "$server_pid" 2>/dev/null; then
    if ! start_dev_server "$task_id"; then
      log_warn "Dev server failed to start, continuing anyway..."
    fi
    # Give server extra time to be ready
    sleep 3
  fi

  # Open browser
  log_browser "Opening browser..."
  local browser_id=""
  local browser_output=""

  browser_output=$(agent-browser open "$full_url" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    log_error "Failed to open browser with agent-browser"
    return 1
  fi

  # Extract browser ID from output
  browser_id=$(echo "$browser_output" | grep -oE 'Browser [A-Za-z0-9\-]+' | head -1 | sed 's/Browser //')

  if [[ -z "$browser_id" ]]; then
    log_error "Could not extract browser ID from agent-browser output"
    log_debug "Output was: $browser_output"
    return 1
  fi

  BROWSER_IDS["$task_id"]="$browser_id"
  log_success "Browser opened: $browser_id"

  # Wait for page to load
  sleep 2

  # Take snapshot
  log_browser "Taking page snapshot..."
  local snapshot=""

  snapshot=$(agent-browser snapshot "$browser_id" -i 2>/dev/null)

  if [[ -n "$snapshot" ]]; then
    log_debug "Snapshot captured (${#snapshot} chars)"

    # Verify elements if provided
    if [[ -n "$elements" ]]; then
      log_browser "Verifying expected elements..."
      if verify_elements_in_snapshot "$snapshot" "$elements"; then
        log_success "All expected elements found"
      else
        log_warn "Some expected elements were missing"
      fi
    fi
  else
    log_warn "Failed to capture snapshot"
  fi

  # Take screenshot for documentation
  local screenshot_path="$BROWSER_SCREENSHOTS_DIR/${task_id}-$(date +%Y%m%d-%H%M%S).png"
  take_browser_screenshot "$browser_id" "$screenshot_path"

  # Close browser
  log_browser "Closing browser..."
  agent-browser close "$browser_id" 2>/dev/null || true
  unset "BROWSER_IDS[$task_id]"

  log_success "Browser verification complete for $task_id"
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Progress Display
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_progress() {
  local pending=$(count_by_status "pending")
  local running=$(count_by_status "running")
  local done=$(count_by_status "done")
  local failed=$(count_by_status "failed")
  local total=${#TASK_STATUS[@]}

  echo -ne "\r${BOLD}Progress:${RESET} "
  echo -ne "${YELLOW}⏳ $pending${RESET} | "
  echo -ne "${BLUE}🔄 $running${RESET} | "
  echo -ne "${GREEN}✓ $done${RESET} | "
  echo -ne "${RED}✗ $failed${RESET} | "
  echo -ne "Total: $total   "
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Parallel Loop
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parallel_loop() {
  local tasks_file=$(mktemp)

  # Parse tasks
  if [[ -n "$PRD_FILE" ]]; then
    parse_tasks_with_deps "$PRD_FILE" > "$tasks_file"
  elif [[ -n "$YAML_FILE" ]]; then
    parse_yaml_tasks "$YAML_FILE" > "$tasks_file"
  elif [[ -n "$SINGLE_TASK" ]]; then
    echo "TASK-SINGLE|$SINGLE_TASK" > "$tasks_file"
    TASK_DEPS["TASK-SINGLE"]=""
    TASK_STATUS["TASK-SINGLE"]="pending"
  fi
  
  # Load task titles
  typeset -A TASK_TITLES
  while IFS='|' read -r task_id task_title; do
    TASK_TITLES["$task_id"]="$task_title"
  done < "$tasks_file"
  rm "$tasks_file"
  
  local total=${#TASK_STATUS[@]}
  
  if [[ $total -eq 0 ]]; then
    log_error "No tasks found"
    return 1
  fi
  
  log_info "Found $total tasks"
  
  # Show dependency graph
  if [[ "$VERBOSE" == true ]]; then
    echo ""
    log_debug "Dependency graph:"
    for task in "${(k)TASK_DEPS}"; do
      local deps="${TASK_DEPS[$task]:-none}"
      log_debug "  $task -> depends on: $deps"
    done
    echo ""
  fi
  
  # Setup worktree directory
  if [[ "$USE_WORKTREES" == true ]]; then
    setup_worktree_dir
    BASE_BRANCH=$(git branch --show-current)
  fi
  
  # Initial Argus refresh
  if [[ "$ARGUS_REFRESH" == true ]]; then
    refresh_argus
  fi
  
  log_info "Starting parallel execution (max $MAX_PARALLEL concurrent)..."
  echo ""
  
  # Main execution loop
  while true; do
    # Check for completed tasks
    for task_id in "${(k)TASK_PID}"; do
      check_task_completion "$task_id" || true
    done
    
    # Launch new tasks if we have capacity
    local ready_tasks=$(get_ready_tasks)
    
    for task_id in $ready_tasks; do
      if [[ $RUNNING_COUNT -lt $MAX_PARALLEL ]]; then
        local title="${TASK_TITLES[$task_id]}"
        launch_task "$task_id" "$title"
      fi
    done
    
    # Show progress
    show_progress
    
    # Check if we're done
    local pending=$(count_by_status "pending")
    local running=$(count_by_status "running")
    
    if [[ $pending -eq 0 && $running -eq 0 ]]; then
      break
    fi
    
    # Short sleep to avoid busy-waiting
    sleep 2
  done
  
  echo ""
  echo ""

  # Merge all completed branches
  if [[ "$USE_WORKTREES" == true ]]; then
    merge_completed_tasks
    cleanup_all_worktrees
  fi

  # Run quality gates after all tasks complete
  if ! run_quality_gates; then
    log_warn "Quality gates failed but continuing..."
  fi

  # Final summary
  local done=$(count_by_status "done")
  local failed=$(count_by_status "failed")

  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}Super Ralphy Complete${RESET}"
  echo -e "  ${GREEN}Completed:${RESET} $done"
  echo -e "  ${RED}Failed:${RESET}    $failed"
  echo -e "  Total:     $total"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  # Write session summary
  write_session_summary

  [[ $failed -gt 0 ]] && return 1
  return 0
}

# Sequential fallback (like original Ralphy)
sequential_loop() {
  log_info "Running in sequential mode..."

  local tasks_file=$(mktemp)

  if [[ -n "$PRD_FILE" ]]; then
    parse_tasks_with_deps "$PRD_FILE" > "$tasks_file"
  elif [[ -n "$YAML_FILE" ]]; then
    parse_yaml_tasks "$YAML_FILE" > "$tasks_file"
  elif [[ -n "$SINGLE_TASK" ]]; then
    echo "TASK-SINGLE|$SINGLE_TASK" > "$tasks_file"
  fi
  
  local completed=0
  local failed=0
  
  while IFS='|' read -r task_id task_title; do
    log_task "[$task_id] $task_title"
    
    local prompt=$(build_prompt "$task_id" "$task_title")
    
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY RUN] Would execute: $task_title"
      ((completed++))
      continue
    fi
    
    if claude -p "$prompt" --dangerously-skip-permissions; then
      log_success "[$task_id] Completed"
      ((completed++))

      if [[ "$NO_COMMIT" != true ]]; then
        git add -A
        git commit -m "feat: $task_title [$task_id]" 2>/dev/null || true
      fi

      # Run quality gates after each task
      if ! run_quality_gates; then
        if [[ "$STRICT_MODE" == true ]]; then
          log_error "Quality gates failed, stopping due to strict mode"
          ((failed++))
          break
        fi
      fi

      # Run browser verification if enabled
      if [[ "$ENABLE_BROWSER" == true ]] || [[ "${TASK_VERIFY_BROWSER[$task_id]:-false}" == "true" ]]; then
        local verify_url="${TASK_VERIFY_URL[$task_id]:-}"
        local verify_elements="${TASK_VERIFY_ELEMENTS[$task_id]:-}"
        verify_browser "$task_id" "$task_title" "$verify_url" "$verify_elements" || true
      fi
    else
      log_error "[$task_id] Failed"
      ((failed++))
      
      if [[ "$STRICT_MODE" == true ]]; then
        break
      fi
    fi
  done < "$tasks_file"

  rm "$tasks_file"

  echo ""
  echo -e "${BOLD}Summary:${RESET} $completed completed, $failed failed"

  # Write session summary for sequential mode
  write_session_summary

  [[ $failed -gt 0 ]] && return 1
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argument Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help; exit 0 ;;
      --version) echo "Super Ralphy v$VERSION"; exit 0 ;;

      # Project Config
      --init) shift; init_config; exit 0 ;;
      --config) shift; load_config; show_config; exit 0 ;;
      --add-rule) shift; add_rule "$1"; exit 0 ;;
      
      # Task sources
      --prd) PRD_FILE="$2"; shift 2 ;;
      --yaml) YAML_FILE="$2"; shift 2 ;;
      
      # Parallel execution
      --parallel) PARALLEL=true; shift ;;
      --max-parallel) MAX_PARALLEL="$2"; shift 2 ;;
      --worktrees) USE_WORKTREES=true; shift ;;
      --no-worktrees) USE_WORKTREES=false; shift ;;
      --ai-merge) AI_MERGE=true; shift ;;
      --no-ai-merge) AI_MERGE=false; shift ;;
      
      # Features
      --agents) ENABLE_AGENTS=true; shift ;;
      --skills) ENABLE_SKILLS=true; shift ;;
      --argus) ENABLE_ARGUS=true; shift ;;
      --argus-refresh) ARGUS_REFRESH=true; ENABLE_ARGUS=true; shift ;;
      --browser) ENABLE_BROWSER=true; shift ;;
      --browser-url) BROWSER_URL="$2"; shift 2 ;;
      --browser-headed) BROWSER_HEADED=true; shift ;;
      --quality-gates) ENABLE_QUALITY_GATES=true; GATE_TEST=true; GATE_LINT=true; GATE_TYPECHECK=true; shift ;;
      --gate-test) ENABLE_QUALITY_GATES=true; GATE_TEST=true; GATE_LINT=false; GATE_TYPECHECK=false; shift ;;
      --gate-lint) ENABLE_QUALITY_GATES=true; GATE_TEST=false; GATE_LINT=true; GATE_TYPECHECK=false; shift ;;
      --gate-typecheck) ENABLE_QUALITY_GATES=true; GATE_TEST=false; GATE_LINT=false; GATE_TYPECHECK=true; shift ;;
      --notes) ENABLE_NOTES=true; shift ;;
      
      # Control
      --no-commit) NO_COMMIT=true; shift ;;
      --max-retries) MAX_RETRIES="$2"; shift 2 ;;
      --strict) STRICT_MODE=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      -v|--verbose) VERBOSE=true; shift ;;
      
      # Unknown
      -*) log_error "Unknown option: $1"; exit 1 ;;
      
      # Single task
      *) SINGLE_TASK="$1"; shift ;;
    esac
  done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  parse_args "$@"

  show_banner
  check_dependencies

  # Load project config if exists
  load_config

  # Apply browser config values from config file (if not overridden by CLI args)
  if [[ -n "${CONFIG_BROWSER[url]:-}" ]]; then
    BROWSER_URL="${CONFIG_BROWSER[url]}"
  fi
  if [[ -n "${CONFIG_BROWSER[headed]:-}" ]]; then
    BROWSER_HEADED="${CONFIG_BROWSER[headed]}"
  fi
  if [[ -n "${CONFIG_BROWSER[dev_command]:-}" ]]; then
    BROWSER_DEV_COMMAND="${CONFIG_BROWSER[dev_command]}"
  fi

  # Initialize working notes
  init_working_notes

  # Choose execution mode
  if [[ "$PARALLEL" == true ]]; then
    parallel_loop
  else
    sequential_loop
  fi
}

# Cleanup on exit
trap cleanup_all_worktrees EXIT
trap stop_all_dev_servers EXIT

main "$@"
