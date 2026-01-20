# Super Ralphy 🦸‍♂️

Enhanced autonomous AI coding loop with sub-agents, skills injection, browser automation, and quality gates.

![Super Ralphy](assets/super-ralphy.png)

## Credits & Inspiration

Super Ralphy stands on the shoulders of giants:

- **[Ralph Wiggum](https://github.com/anthropics/claude-code)** - The original autonomous coding loop concept by Anthropic
- **[Ralphy](https://github.com/michaelshimeles/ralphy)** by [@michaelshimeles](https://github.com/michaelshimeles) - Enhanced version with parallel execution, multi-engine support, and git worktrees
- **[agent-browser](https://github.com/vercel-labs/agent-browser)** by Vercel Labs - Browser automation CLI for AI agents

Super Ralphy adds sub-agent specialization, skills injection, codebase intelligence, browser verification, and quality gates on top of these foundations.

---

## What's Different?

| Feature | Ralph Wiggum | Ralphy | Super Ralphy |
|---------|--------------|--------|--------------|
| Task loop | ✅ | ✅ | ✅ |
| Multi-engine | ❌ | ✅ | ✅ |
| Parallel execution | ❌ | ✅ | ✅ |
| Git worktrees | ❌ | ✅ | ✅ |
| **Sub-agents** | ❌ | ❌ | ✅ |
| **Skills injection** | ❌ | ❌ | ✅ |
| **Argus integration** | ❌ | ❌ | ✅ |
| **Browser verification** | ❌ | ❌ | ✅ |
| **Quality gates** | ❌ | ❌ | ✅ |
| **Working notes** | ❌ | ❌ | ✅ |
| **PM mode** | ❌ | ❌ | ✅ |

---

## Installation

### Option A: npm (recommended)

```bash
npm install -g super-ralphy

# Then use anywhere
super-ralphy "add login button"
super-ralphy --prd PRD.md
```

### Option B: Clone

```bash
git clone https://github.com/sashabogi/super-ralphy.git
cd super-ralphy && chmod +x super-ralphy.sh

./super-ralphy.sh "add login button"
./super-ralphy.sh --prd PRD.md
```

---

## Quick Start

**Single task:**
```bash
super-ralphy "add dark mode"
super-ralphy "fix the auth bug"
```

**Task list (PRD):**
```bash
super-ralphy                    # uses PRD.md or TODO.md
super-ralphy --prd tasks.md
```

**With sub-agents:**
```bash
super-ralphy --agents           # auto-route to coder/tester/reviewer
```

**With browser verification:**
```bash
super-ralphy --browser          # verify UI changes in real browser
```

**Full autonomous mode:**
```bash
super-ralphy --agents --skills --argus --browser --quality-gates
```

---

## Browser Automation (agent-browser)

Super Ralphy integrates [Vercel's agent-browser](https://github.com/vercel-labs/agent-browser) for real browser verification. This lets the AI actually see and interact with your app - with 93% less context than screenshots.

### Setup

```bash
# Install agent-browser globally
npm install -g agent-browser
agent-browser install  # Download Chromium
```

### Usage

```bash
super-ralphy --browser "fix the login form validation"
# → After coding, opens browser to verify the fix works

super-ralphy --browser --browser-url "http://localhost:3000"
# → Uses custom dev server URL

super-ralphy --browser --browser-headed
# → Shows visible browser window (default is headless)
```

### How It Works

1. Agent completes coding task
2. Starts dev server (auto-detected or configured)
3. Opens browser with `agent-browser open <url>`
4. Takes snapshot with `agent-browser snapshot -i`
5. Verifies expected elements exist
6. Takes screenshot for documentation
7. Closes browser and continues to next task

### Browser Verification in YAML Tasks

```yaml
tasks:
  - title: Add login form
    verify_browser: true
    verify_url: "/login"
    verify_elements:
      - "input[name='email']"
      - "input[name='password']"
      - "button[type='submit']"
  
  - title: Add dark mode toggle
    verify_browser: true
    verify_screenshot: true  # Save screenshot after verification
```

### Why agent-browser Over Chrome Extension?

| Feature | Chrome Extension | agent-browser |
|---------|-----------------|---------------|
| Context usage | High (full DOM/screenshots) | **93% less** (snapshot + refs) |
| Headless mode | ❌ | ✅ |
| CI/CD compatible | ❌ | ✅ |
| Zero config | ❌ | ✅ |
| Element refs | ❌ | ✅ (@e1, @e2) |
| Works in loops | Awkward | **Native** |

---

## Sub-Agent System

Super Ralphy routes tasks to specialized agents based on keywords:

| Keywords | Agent | Focus |
|----------|-------|-------|
| `test`, `spec`, `coverage` | **Tester** | Write and fix tests |
| `review`, `audit`, `verify` | **Reviewer** | Code review, security |
| `document`, `readme`, `docs` | **Documenter** | Documentation |
| `browser`, `ui`, `visual` | **Browser** | UI verification |
| *(default)* | **Coder** | Implementation |

Each agent gets tailored prompts and can have custom instructions in `.claude/agents/`.

```bash
super-ralphy --agents "write tests for auth module"
# → Routes to Tester agent with testing-focused prompt
```

---

## Skills Injection

If your project has `.claude/skills/`, Super Ralphy injects relevant patterns:

```
.claude/skills/
├── convex/SKILL.md        # Convex patterns
├── nextjs/SKILL.md        # Next.js patterns
├── testing/SKILL.md       # Testing patterns
├── agent-browser/SKILL.md # Browser automation patterns
└── ...
```

Task keywords trigger skill loading:

| Keywords | Skills Loaded |
|----------|---------------|
| `convex`, `mutation`, `query`, `schema` | convex |
| `page`, `component`, `react`, `nextjs` | nextjs |
| `test`, `spec`, `coverage` | testing |
| `browser`, `ui`, `verify`, `visual` | agent-browser |

```bash
super-ralphy --skills "create convex mutation for users"
# → Injects Convex patterns into the prompt
```

### Auto-Install Dependencies

```bash
# Install Argus MCP for codebase intelligence
super-ralphy --install-argus

# Install agent-browser for browser automation
super-ralphy --install-browser

# Install agent-browser skill for Claude Code
super-ralphy --install-skill agent-browser

# Install Vercel's agent-skills (React best practices, web design guidelines)
npx add-skill vercel-labs/agent-skills
```

---

## Argus Integration

[Argus](https://github.com/sashabogi/argus) provides codebase intelligence without burning context.

```bash
super-ralphy --argus            # Enable with enhanced snapshots
super-ralphy --argus-refresh    # Force refresh before run
```

Super Ralphy uses **enhanced snapshots** by default, which include:

| Feature | What It Provides | Cost |
|---------|-----------------|------|
| Import Graph | Who imports what file | FREE |
| Export Index | Symbol → files that export it | FREE |
| Who Imports Whom | Reverse dependency graph | FREE |
| Function Signatures | With line numbers | FREE |

### How Claude Code Uses This

Instead of reading 15 files to understand a flow, Claude Code can now:

```
find_symbol("useAuth")           → "contexts/auth-context.tsx:42"
find_importers("auth-context")   → ["app.tsx", "dashboard.tsx", ...]
get_file_deps("app.tsx")         → ["./auth", "./theme", "@/components/ui"]
```

### Install Argus

```bash
super-ralphy --install-argus     # Install with enhanced features
# Or manually:
npm install -g github:sashabogi/argus
```

---

## Quality Gates

Run checks between tasks to catch issues early:

```bash
super-ralphy --quality-gates    # run tests + lint between tasks
super-ralphy --gate-test        # only run tests
super-ralphy --gate-lint        # only run lint
super-ralphy --gate-typecheck   # only run typecheck
```

If a gate fails, Super Ralphy:
1. Logs the failure
2. Attempts to fix (up to 3 retries)
3. Continues or stops based on `--strict` flag

---

## Working Notes

Track progress across sessions:

```bash
super-ralphy --notes            # write to docs/claude/working-notes/
```

Creates timestamped session files:
```
docs/claude/working-notes/
└── session-2026-01-20-103045.md
```

Useful for:
- Handoff between sessions
- Debugging failed runs
- Understanding what was done

---

## Project Config

Auto-detect or manually configure:

```bash
super-ralphy --init             # auto-detect project settings
super-ralphy --config           # view current config
super-ralphy --add-rule "use TypeScript strict mode"
```

Creates `.super-ralphy/config.yaml`:

```yaml
project:
  name: "my-app"
  language: "TypeScript"
  framework: "Next.js"

commands:
  test: "npm test"
  lint: "npm run lint"
  build: "npm run build"
  dev: "npm run dev"  # for browser verification

rules:
  - "use server actions not API routes"
  - "delegate to sub-agents, never code directly"

boundaries:
  never_touch:
    - "src/legacy/**"
    - "*.lock"
    - ".env*"

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
  refresh_interval: 5  # tasks

browser:
  enabled: false
  url: "http://localhost:3000"
  headed: false
  dev_command: "npm run dev"

quality_gates:
  enabled: true
  test: true
  lint: true
  typecheck: false
```

---

## AI Engines

```bash
super-ralphy                    # Claude Code (default)
super-ralphy --opencode         # OpenCode
super-ralphy --cursor           # Cursor
super-ralphy --codex            # Codex
super-ralphy --qwen             # Qwen-Code
super-ralphy --droid            # Factory Droid
```

---

## Task Sources

**Markdown** (default):
```bash
super-ralphy --prd PRD.md
super-ralphy --prd TODO.md
```

```markdown
## Tasks
- [ ] create auth
- [ ] add dashboard
- [x] done task (skipped)
```

**YAML**:
```bash
super-ralphy --yaml tasks.yaml
```

```yaml
tasks:
  - title: create auth
    agent: coder
    skills: [convex, nextjs]
  - title: write auth tests
    agent: tester
  - title: verify login UI
    agent: browser
    verify_browser: true
    verify_url: "/login"
```

**GitHub Issues**:
```bash
super-ralphy --github owner/repo
super-ralphy --github owner/repo --github-label "ready"
```

---

## Parallel Execution

```bash
super-ralphy --parallel                  # 3 agents default
super-ralphy --parallel --max-parallel 5 # 5 agents
```

Each agent gets isolated worktree + branch:
```
Agent 1 → /tmp/xxx/agent-1 → super-ralphy/agent-1-create-auth
Agent 2 → /tmp/xxx/agent-2 → super-ralphy/agent-2-add-dashboard
```

**YAML parallel groups:**
```yaml
tasks:
  - title: Create User model
    parallel_group: 1
  - title: Create Post model
    parallel_group: 1      # runs together
  - title: Add relationships
    parallel_group: 2      # runs after group 1
```

---

## Branch Workflow

```bash
super-ralphy --branch-per-task              # branch per task
super-ralphy --branch-per-task --create-pr  # + create PRs
super-ralphy --branch-per-task --draft-pr   # + draft PRs
super-ralphy --base-branch main             # branch from main
```

---

## All Options

| Flag | Description |
|------|-------------|
| **Task Sources** | |
| `--prd FILE` | Markdown task file (default: PRD.md or TODO.md) |
| `--yaml FILE` | YAML task file |
| `--github REPO` | Use GitHub issues |
| `--github-label TAG` | Filter issues by label |
| **Super Ralphy Features** | |
| `--agents` | Enable sub-agent routing |
| `--skills` | Enable skills injection |
| `--argus` | Enable Argus codebase intelligence |
| `--argus-refresh` | Force Argus snapshot refresh |
| `--browser` | Enable browser verification |
| `--browser-url URL` | Dev server URL (default: http://localhost:3000) |
| `--browser-headed` | Show visible browser window |
| `--quality-gates` | Run quality checks between tasks |
| `--gate-test` | Run tests as quality gate |
| `--gate-lint` | Run lint as quality gate |
| `--gate-typecheck` | Run typecheck as quality gate |
| `--notes` | Write session working notes |
| `--pm-mode` | Enforce PM mode (delegate only) |
| `--install-skill NAME` | Install a skill to .claude/skills/ |
| `--install-argus` | Install Argus MCP for codebase intelligence |
| `--install-browser` | Install agent-browser for browser automation |
| **Execution** | |
| `--parallel` | Run tasks in parallel |
| `--max-parallel N` | Max parallel agents (default: 3) |
| `--branch-per-task` | Create branch per task |
| `--base-branch NAME` | Base branch for branching |
| `--create-pr` | Create PRs for branches |
| `--draft-pr` | Create draft PRs |
| **Control** | |
| `--no-tests` | Skip test commands |
| `--no-lint` | Skip lint commands |
| `--fast` | Skip tests + lint |
| `--no-commit` | Don't auto-commit |
| `--max-iterations N` | Stop after N tasks |
| `--max-retries N` | Retries per task (default: 3) |
| `--retry-delay N` | Seconds between retries |
| `--strict` | Stop on any failure |
| `--dry-run` | Preview without executing |
| `-v, --verbose` | Debug output |
| **Config** | |
| `--init` | Setup .super-ralphy/ config |
| `--config` | Show current config |
| `--add-rule "rule"` | Add rule to config |
| **Engines** | |
| `--opencode` | Use OpenCode |
| `--cursor` | Use Cursor |
| `--codex` | Use Codex |
| `--qwen` | Use Qwen-Code |
| `--droid` | Use Factory Droid |

---

## Requirements

**Required:**
- AI CLI: [Claude Code](https://github.com/anthropics/claude-code), [OpenCode](https://opencode.ai/docs/), [Cursor](https://cursor.com), Codex, Qwen-Code, or [Factory Droid](https://docs.factory.ai/cli/getting-started/quickstart)
- `jq`
- `bash` 3.2+ (macOS default works)

**Optional:**
- `yq` - for YAML tasks
- `gh` - for GitHub issues / `--create-pr`
- [agent-browser](https://github.com/vercel-labs/agent-browser) - for browser verification
- [Argus MCP](https://github.com/sashabogi/argus) - for codebase intelligence

---

## Examples

**Full autonomous run with all features:**
```bash
super-ralphy --agents --skills --argus --browser --quality-gates --notes
```

**Quick single task:**
```bash
super-ralphy "fix the login bug"
```

**Build a feature with browser verification:**
```bash
super-ralphy --browser --prd feature-tasks.md
```

**Parallel execution with PRs:**
```bash
super-ralphy --parallel --branch-per-task --create-pr --prd PRD.md
```

**PM mode (orchestrate only, never code directly):**
```bash
super-ralphy --pm-mode --agents --prd PRD.md
```

---

## License

MIT

---

## Contributing

PRs welcome! Please read the contributing guidelines first.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
