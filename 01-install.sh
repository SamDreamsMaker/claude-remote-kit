#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# CLAUDE CODE AGENT - FULL INSTALLATION SCRIPT
# For Ubuntu Server with Max subscription (no API key needed)
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   CLAUDE CODE AGENT INSTALLATION - Ubuntu Server (Max)       ${NC}"
echo -e "${BLUE}   Step 1 of 2: Install                                       ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo ""

# ── Pre-checks ──
info "Checking environment..."

if [ "$(id -u)" -eq 0 ]; then
    warn "This script must NOT be run as root."
    warn "Run it with your normal user (who has sudo access)."
    exit 1
fi

if ! command -v sudo &> /dev/null; then
    err "sudo is not installed. Install it first."
    exit 1
fi

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
log "Detected system: $OS_ID $OS_VERSION"

# ── Step 1: System dependencies ──
info "Installing system dependencies..."
echo ""
echo -e "  ${YELLOW}Your sudo password may be required below.${NC}"
echo ""
sudo apt-get update -qq
sudo apt-get install -y -qq \
    curl git jq build-essential \
    ripgrep unzip screen > /dev/null 2>&1

# Ensure screen directory exists (needed on WSL2)
if [ ! -d /run/screen ]; then
    sudo mkdir -p /run/screen
    sudo chmod 777 /run/screen
fi
log "System dependencies installed"

# Check/install Node.js (required for MCP servers)
if ! command -v node &> /dev/null; then
    info "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - > /dev/null 2>&1
    sudo apt-get install -y -qq nodejs > /dev/null 2>&1
    log "Node.js $(node -v) installed"
else
    log "Node.js $(node -v) already present"
fi

# ── Step 2: Install Claude Code ──
info "Installing Claude Code..."
if command -v claude &> /dev/null; then
    log "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
    info "Updating to latest version..."
    sudo npm install -g @anthropic-ai/claude-code@latest > /dev/null 2>&1 || claude update 2>/dev/null || true
    log "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
else
    curl -fsSL https://claude.ai/install.sh | bash
    # Reload PATH
    export PATH="$HOME/.local/bin:$PATH"
    if command -v claude &> /dev/null; then
        log "Claude Code installed successfully: $(claude --version 2>/dev/null || echo '')"
    else
        err "Claude Code installation failed"
        exit 1
    fi
fi

# Install Bun (required by Telegram plugin)
if ! command -v bun &> /dev/null; then
    info "Installing Bun (required for Telegram plugin)..."
    sudo npm install -g bun > /dev/null 2>&1
    if command -v bun &> /dev/null; then
        log "Bun installed: $(bun --version)"
    else
        err "Bun installation failed. Telegram plugin will not work."
        err "Try manually: sudo npm install -g bun"
    fi
else
    log "Bun already present: $(bun --version 2>/dev/null)"
fi

# Add to PATH permanently
if ! grep -q 'claude' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    log "PATH updated in ~/.bashrc"
fi

# Disable auto-updates
if ! grep -q 'DISABLE_AUTOUPDATER' ~/.bashrc 2>/dev/null; then
    echo 'export DISABLE_AUTOUPDATER=1' >> ~/.bashrc
fi

# ── Step 3: Create directory structure ──
info "Creating directory structure..."

AGENT_HOME="$HOME/claude-agent"
mkdir -p "$AGENT_HOME"/{scripts,logs,config}
mkdir -p "$HOME/.claude"

log "Directory structure created in $AGENT_HOME"

# ── Step 4: Claude Code configuration ──
info "Installing configuration..."

# Global settings
cat > "$HOME/.claude/settings.json" << 'SETTINGS_EOF'
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  },
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Glob",
      "Grep",
      "Write",
      "Skill",
      "Agent",
      "CronCreate",
      "CronDelete",
      "CronList",
      "RemoteTrigger",
      "WebFetch",
      "WebSearch",
      "TodoWrite",
      "NotebookEdit",
      "Bash(npm run *)",
      "Bash(npm test *)",
      "Bash(npm audit *)",
      "Bash(npm outdated *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(python3 *)",
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git branch *)",
      "Bash(git checkout *)",
      "Bash(git fetch *)",
      "Bash(git pull *)",
      "Bash(git push origin *)",
      "Bash(git stash *)",
      "Bash(cat *)",
      "Bash(ls *)",
      "Bash(find *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(wc *)",
      "Bash(sort *)",
      "Bash(grep *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(echo *)",
      "Bash(date *)",
      "Bash(which *)",
      "Bash(sudo *)",
      "Bash(su *)",
      "Bash(rm -rf /)",
      "Bash(rm -rf /*)",
      "Bash(curl * | bash)",
      "Bash(curl * | sh)",
      "Bash(wget * | bash)",
      "Bash(wget * | sh)",
      "Bash(git push --force *)",
      "Bash(git push -f *)",
      "Bash(git reset --hard *)",
      "Bash(shutdown *)",
      "Bash(reboot *)",
      "Bash(mkfs *)",
      "Bash(dd if=*)",
      "Bash(chmod 777 *)",
      "Edit(.env)",
      "Edit(.env.*)",
      "Edit(*.pem)",
      "Edit(*.key)",
      "Edit(*secret*)",
      "Edit(*credential*)",
      "Edit(*password*)"
    ],
    "deny": [],
    "defaultMode": "bypassPermissions"
  },
  "enabledPlugins": {
    "telegram@claude-plugins-official": true
  },
  "channelsEnabled": true,
  "skipDangerousModePermissionPrompt": true,
  "voiceEnabled": true,
  "voice": {
    "enabled": true,
    "mode": "hold"
  }
}
SETTINGS_EOF
log "Global settings installed"

# ── Step 5: Security hooks ──
info "Installing security hooks..."

mkdir -p "$AGENT_HOME/config/hooks"

cat > "$AGENT_HOME/config/hooks/validate-bash.sh" << 'HOOK_EOF'
#!/bin/bash
# PreToolUse hook: validates Bash commands before execution
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command' 2>/dev/null)

if [ -z "$COMMAND" ] || [ "$COMMAND" = "null" ]; then
    exit 0
fi

# Dangerous patterns (defense in depth, on top of deny rules)
DANGEROUS_PATTERNS=(
    "rm -rf /"
    "rm -rf /*"
    ":(){ :|:& };:"
    "fork bomb"
    "DROP TABLE"
    "DROP DATABASE"
    "TRUNCATE"
    "curl.*|.*bash"
    "curl.*|.*sh"
    "wget.*|.*bash"
    "wget.*|.*sh"
    "> /dev/sda"
    "mkfs\."
    "dd if="
    "chmod -R 777 /"
    "shutdown"
    "reboot"
    "init 0"
    "init 6"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        echo "BLOCKED by security hook: pattern '$pattern' detected in command" >&2
        exit 2
    fi
done

# Block access to sensitive files
SENSITIVE_PATHS=(
    "/etc/shadow"
    "/etc/passwd"
    "/root/"
    "~/.ssh/id_"
    ".env"
    "credentials"
    "secret"
)

for path in "${SENSITIVE_PATHS[@]}"; do
    if echo "$COMMAND" | grep -qi "cat.*$path\|less.*$path\|more.*$path\|head.*$path\|tail.*$path"; then
        echo "BLOCKED: access to sensitive file ($path)" >&2
        exit 2
    fi
done

exit 0
HOOK_EOF
chmod +x "$AGENT_HOME/config/hooks/validate-bash.sh"
log "Security hooks installed"

# ── Step 6: Agent scripts ──
info "Installing agent scripts..."

# --- General purpose agent ---
cat > "$AGENT_HOME/scripts/agent-run.sh" << 'AGENT_EOF'
#!/bin/bash
# ── General purpose Claude Code agent ──
# Usage: ./agent-run.sh "Your task" [project_directory] [max_turns]
set -euo pipefail


TASK="${1:?Usage: $0 \"task description\" [project_directory] [max_turns]}"
PROJECT_DIR="${2:-$(pwd)}"
MAX_TURNS="${3:-15}"
LOG_DIR="$HOME/claude-agent/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/run_${TIMESTAMP}.json"

mkdir -p "$LOG_DIR"
cd "$PROJECT_DIR"

echo "[$(date)] Starting agent: $TASK"
echo "[$(date)] Project: $PROJECT_DIR"
echo "[$(date)] Max turns: $MAX_TURNS"

claude --bare -p "$TASK" \
  --permission-mode bypassPermissions \
  --max-turns "$MAX_TURNS" \
  --output-format json > "$LOG_FILE" 2>&1

SESSION_ID=$(jq -r '.session_id // "N/A"' "$LOG_FILE" 2>/dev/null)
echo "[$(date)] Done. Session: $SESSION_ID"
echo "[$(date)] Log: $LOG_FILE"

# Display summary
echo ""
echo "-- Result --"
jq -r '.result // "No result"' "$LOG_FILE" 2>/dev/null | head -20
AGENT_EOF
chmod +x "$AGENT_HOME/scripts/agent-run.sh"

# --- Code review agent ---
cat > "$AGENT_HOME/scripts/agent-review.sh" << 'REVIEW_EOF'
#!/bin/bash
# ── Code review agent ──
# Usage: ./agent-review.sh [branch] [base] [project_directory]
set -euo pipefail


PROJECT_DIR="${3:-$(pwd)}"
cd "$PROJECT_DIR"

BRANCH="${1:-$(git branch --show-current)}"
BASE="${2:-main}"
LOG_DIR="$HOME/claude-agent/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/review_${TIMESTAMP}.json"

mkdir -p "$LOG_DIR"

# Get diff
DIFF=$(git diff "$BASE".."$BRANCH" 2>/dev/null || git diff HEAD~1 2>/dev/null || echo "No diff available")

if [ -z "$DIFF" ] || [ "$DIFF" = "No diff available" ]; then
    echo "No differences found between $BASE and $BRANCH"
    exit 0
fi

PROMPT="You are a senior code reviewer. Analyze this git diff between $BASE and $BRANCH.

Produce a structured review covering:
1. Potential bugs or logic errors
2. Performance issues (unnecessary allocations, algorithmic complexity)
3. SOLID principle violations and best practice issues
4. Security concerns
5. Concrete improvement suggestions
6. Final verdict: APPROVE, REQUEST_CHANGES, or COMMENT

Be precise, cite the relevant lines.

Diff:
$DIFF"

echo "[$(date)] Code review: $BRANCH vs $BASE"

claude --bare -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --allowedTools "Read,Glob,Grep" \
  --max-turns 8 \
  --output-format json > "$LOG_FILE" 2>&1

echo ""
echo "-- Code Review --"
jq -r '.result // "No result"' "$LOG_FILE" 2>/dev/null
REVIEW_EOF
chmod +x "$AGENT_HOME/scripts/agent-review.sh"

# --- Maintenance agent ---
cat > "$AGENT_HOME/scripts/agent-maintenance.sh" << 'MAINT_EOF'
#!/bin/bash
# ── Daily maintenance agent ──
# Usage: ./agent-maintenance.sh [project_directory]
set -euo pipefail


PROJECT_DIR="${1:-$(pwd)}"
cd "$PROJECT_DIR"

LOG_DIR="$HOME/claude-agent/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/maintenance_${TIMESTAMP}.json"

mkdir -p "$LOG_DIR"

PROMPT="Perform maintenance on this project:

1. Check for outdated dependencies (npm outdated or pip list --outdated depending on the project)
2. Run the test suite if a test script exists
3. Check for vulnerabilities (npm audit or safety check)
4. Verify the build passes
5. Identify TODO/FIXME/HACK in the code
6. Generate a summary report with:
   - Overall project status (green/yellow/red)
   - Dependencies to update
   - Vulnerabilities found
   - Failing tests
   - Recommended actions"

echo "[$(date)] Maintenance: $PROJECT_DIR"

claude --bare -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --max-turns 12 \
  --output-format json > "$LOG_FILE" 2>&1

echo ""
echo "-- Maintenance Report --"
jq -r '.result // "No result"' "$LOG_FILE" 2>/dev/null

# Archive old logs (keep 30 days)
find "$LOG_DIR" -name "maintenance_*.json" -mtime +30 -delete 2>/dev/null || true
MAINT_EOF
chmod +x "$AGENT_HOME/scripts/agent-maintenance.sh"

# --- Autonomous development agent ---
cat > "$AGENT_HOME/scripts/agent-dev.sh" << 'DEV_EOF'
#!/bin/bash
# ── Autonomous development agent ──
# Usage: ./agent-dev.sh "feature/fix description" [project_directory] [branch]
set -euo pipefail


TASK="${1:?Usage: $0 \"task description\" [project_directory] [branch]}"
PROJECT_DIR="${2:-$(pwd)}"
BRANCH="${3:-agent/$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | head -c 50)}"
LOG_DIR="$HOME/claude-agent/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/dev_${TIMESTAMP}.json"

mkdir -p "$LOG_DIR"
cd "$PROJECT_DIR"

# Create a dedicated branch
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

PROMPT="You are a senior developer. Your mission:

$TASK

Process to follow:
1. Analyze the existing codebase to understand the architecture
2. Plan the necessary changes
3. Implement the changes
4. Run tests to verify (npm test or equivalent)
5. If tests fail, fix until they pass
6. Commit the work with a descriptive commit message

Principles to follow:
- Clean Architecture, SOLID, Single Responsibility
- No placeholder code, production-ready code
- Explicit naming, no magic numbers
- Tests if applicable
- Intent comments only"

echo "[$(date)] Autonomous dev: $TASK"
echo "[$(date)] Branch: $BRANCH"

claude --bare -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --max-turns 25 \
  --output-format json > "$LOG_FILE" 2>&1

echo ""
echo "-- Development Result --"
jq -r '.result // "No result"' "$LOG_FILE" 2>/dev/null
echo ""
echo "-- Commits Created --"
git log --oneline "$BRANCH" --not main 2>/dev/null | head -10
DEV_EOF
chmod +x "$AGENT_HOME/scripts/agent-dev.sh"

log "4 agent scripts installed"

# ── Step 6b: Clone the full kit from GitHub ──
KIT_DIR="$HOME/claude-remote-kit"
REPO_URL="https://github.com/SamDreamsMaker/claude-remote-kit.git"

info "Fetching full kit from GitHub..."
if [ -d "$KIT_DIR/.git" ]; then
    (cd "$KIT_DIR" && git pull --quiet 2>/dev/null) || true
    log "Kit updated at $KIT_DIR"
else
    rm -rf "$KIT_DIR" 2>/dev/null || true
    git clone --quiet "$REPO_URL" "$KIT_DIR"
    log "Kit downloaded to $KIT_DIR"
fi

chmod +x "$KIT_DIR/01-install.sh" 2>/dev/null || true
chmod +x "$KIT_DIR/02-install-telegram.sh" 2>/dev/null || true
chmod +x "$KIT_DIR/start-claude-telegram.sh" 2>/dev/null || true

# ── Step 7: Diagnostic script ──
cat > "$AGENT_HOME/scripts/doctor.sh" << 'DOCTOR_EOF'
#!/bin/bash
# ── Claude Agent installation diagnostic ──
echo ""
echo "== Claude Code Agent Diagnostic =="
echo ""

# Check Claude Code
if command -v claude &> /dev/null; then
    echo "OK - Claude Code: $(claude --version 2>/dev/null || echo 'installed')"
else
    echo "FAIL - Claude Code: NOT installed"
fi

# Check authentication
if claude -p "say ok" --output-format json > /dev/null 2>&1; then
    echo "OK - Authentication: valid"
else
    echo "FAIL - Authentication: EXPIRED or invalid"
    echo "   -> Reattach to a screen session and follow the sign-in URL"
    echo "   -> Or run: claude login"
fi

# Check Node.js
if command -v node &> /dev/null; then
    echo "OK - Node.js: $(node -v)"
else
    echo "FAIL - Node.js: NOT installed"
fi

# Check dependencies
for cmd in git jq curl rg screen; do
    if command -v "$cmd" &> /dev/null; then
        echo "OK - $cmd: installed"
    else
        echo "FAIL - $cmd: MISSING"
    fi
done

# Check configuration
if [ -f "$HOME/.claude/settings.json" ]; then
    echo "OK - Settings: $HOME/.claude/settings.json"
else
    echo "FAIL - Settings: MISSING"
fi

# Check hooks
if [ -f "$HOME/claude-agent/config/hooks/validate-bash.sh" ]; then
    echo "OK - Security hooks: installed"
else
    echo "FAIL - Security hooks: MISSING"
fi

# Check scripts
SCRIPTS_DIR="$HOME/claude-agent/scripts"
for script in agent-run.sh agent-review.sh agent-maintenance.sh agent-dev.sh; do
    if [ -x "$SCRIPTS_DIR/$script" ]; then
        echo "OK - $script: ready"
    else
        echo "FAIL - $script: MISSING or not executable"
    fi
done

# Check Telegram sessions
BOTS_DIR="$HOME/claude-agent/bots"
if [ -d "$BOTS_DIR" ] && ls "$BOTS_DIR"/*.conf &>/dev/null; then
    echo ""
    echo "-- Telegram Sessions --"
    for conf in "$BOTS_DIR"/*.conf; do
        name=$(basename "$conf" .conf)
        screen_name="claude-tg-$name"
        if screen -list 2>/dev/null | grep -q "$screen_name"; then
            echo "OK - $name: running"
        else
            echo "STOPPED - $name: not running"
        fi
    done
fi

# Disk space
DISK_FREE=$(df -h "$HOME" | awk 'NR==2{print $4}')
echo ""
echo "Disk space available: $DISK_FREE"

# Logs
LOG_COUNT=$(find "$HOME/claude-agent/logs" -name "*.json" 2>/dev/null | wc -l)
echo "Log files: $LOG_COUNT"

echo ""
echo "== End of diagnostic =="
DOCTOR_EOF
chmod +x "$AGENT_HOME/scripts/doctor.sh"

# ── Final summary ──
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   STEP 1 of 2 COMPLETE!                                      ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Everything is installed in: $AGENT_HOME${NC}"
echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   NEXT: Step 2 of 2 - Connect Telegram                      ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  The next script will:"
echo "  - Create a Telegram bot session"
echo "  - Launch Claude Code (which will ask you to sign in)"
echo "  - Connect it to your Telegram bot"
echo ""
echo -e "  Run:"
echo ""
echo -e "  ${BLUE}$KIT_DIR/02-install-telegram.sh${NC}"
echo ""
