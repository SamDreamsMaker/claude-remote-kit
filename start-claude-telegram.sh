#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# Claude Code Telegram — Multi-Bot Session Manager
# Each bot has its own token, workspace, and isolated context.
#
# Usage:
#   start-claude-telegram.sh <session-name>    Start a session
#   start-claude-telegram.sh --list            List all sessions
#   start-claude-telegram.sh --stop <name>     Stop a session
#   start-claude-telegram.sh --stop-all        Stop all sessions
#   start-claude-telegram.sh --start-all       Start all sessions
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

AGENT_HOME="$HOME/claude-agent"
BOTS_DIR="$AGENT_HOME/bots"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pre_accept_trust() {
    local WORK_DIR="$1"
    local CLAUDE_JSON="$HOME/.claude.json"

    [ -z "$WORK_DIR" ] && return 0
    [ ! -f "$CLAUDE_JSON" ] && return 0
    command -v python3 >/dev/null 2>&1 || return 0

    WORK_DIR="$WORK_DIR" python3 - "$CLAUDE_JSON" <<'PY' 2>/dev/null || true
import json, os, sys
path = sys.argv[1]
wd = os.environ["WORK_DIR"]
try:
    with open(path) as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
projects = d.setdefault("projects", {})
proj = projects.setdefault(wd, {
    "allowedTools": [], "mcpContextUris": [], "mcpServers": {},
    "enabledMcpjsonServers": [], "disabledMcpjsonServers": [],
    "history": [], "exampleFiles": [], "exampleFilesGeneratedAt": 0,
})
if proj.get("hasTrustDialogAccepted") is True:
    sys.exit(0)
proj["hasTrustDialogAccepted"] = True
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
os.replace(tmp, path)
PY
}

usage() {
    echo ""
    echo -e "${BLUE}Claude Code Telegram — Multi-Bot Manager${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 <session-name>      Start a bot session"
    echo "  $0 --list              List all bots and their status"
    echo "  $0 --start-all         Start all bots"
    echo "  $0 --stop <name>       Stop a bot"
    echo "  $0 --stop-all          Stop all bots"
    echo ""
    echo "Each bot runs in its own screen with its own Telegram token."
    echo "Add a new bot: run 02-install-telegram.sh"
    echo ""
}

start_session() {
    local SESSION_NAME="$1"
    local CONF_FILE="$BOTS_DIR/$SESSION_NAME.conf"
    local SCREEN_NAME="claude-tg-$SESSION_NAME"

    if [ ! -f "$CONF_FILE" ]; then
        echo -e "${RED}[ERR]${NC} No configuration found for '$SESSION_NAME'"
        echo "  Expected: $CONF_FILE"
        echo "  Run 02-install-telegram.sh to create a new bot."
        exit 1
    fi

    # Load configuration
    source "$CONF_FILE"
    WORK_DIR="${WORK_DIR:-$HOME}"
    BOT_TOKEN="${BOT_TOKEN:-}"

    if [ -z "$BOT_TOKEN" ]; then
        echo -e "${RED}[ERR]${NC} No BOT_TOKEN in $CONF_FILE"
        echo "  Edit the file and add: BOT_TOKEN=\"your_token_here\""
        exit 1
    fi

    # Check if already running
    if screen -list 2>/dev/null | grep -q "$SCREEN_NAME"; then
        echo -e "${YELLOW}[!!]${NC} '$SESSION_NAME' is already running."
        echo "  Attach : screen -r $SCREEN_NAME"
        echo "  Restart: $0 --stop $SESSION_NAME && $0 $SESSION_NAME"
        return 0
    fi

    # Create working directory if needed
    mkdir -p "$WORK_DIR" 2>/dev/null || true

    # Pre-accept the "trust folder" dialog for this workspace.
    # Without this, a freshly-created workspace shows an interactive trust
    # prompt on first launch — and until it's confirmed, the Telegram
    # channel polling never starts, so inbound messages silently time out.
    pre_accept_trust "$WORK_DIR"

    # Launch Claude with isolated bot token via env var
    # This ensures each bot uses its own token, not the shared .env
    # exec replaces the bash wrapper so claude becomes the screen's session
    # leader — required for the telegram MCP plugin server to spawn.
    screen -dmS "$SCREEN_NAME" bash -c "cd \"$WORK_DIR\" && TELEGRAM_BOT_TOKEN=\"$BOT_TOKEN\" exec claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --permission-mode bypassPermissions"

    sleep 2

    if screen -list 2>/dev/null | grep -q "$SCREEN_NAME"; then
        echo -e "${GREEN}[OK]${NC} Bot '$SESSION_NAME' started"
        echo "  Directory : $WORK_DIR"
        echo "  Bot token : ${BOT_TOKEN:0:10}..."
        echo "  Attach    : screen -r $SCREEN_NAME"
        echo "  Detach    : Ctrl+A then D"
    else
        echo -e "${RED}[ERR]${NC} Failed to start '$SESSION_NAME'"
        exit 1
    fi
}

stop_session() {
    local SESSION_NAME="$1"
    local SCREEN_NAME="claude-tg-$SESSION_NAME"

    if screen -list 2>/dev/null | grep -q "$SCREEN_NAME"; then
        screen -S "$SCREEN_NAME" -X quit
        echo -e "${GREEN}[OK]${NC} '$SESSION_NAME' stopped"
    else
        echo -e "${YELLOW}[!!]${NC} '$SESSION_NAME' not running"
    fi
}

list_sessions() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}   Claude Telegram — Bot Central          ${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo ""

    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls "$BOTS_DIR"/*.conf 2>/dev/null)" ]; then
        echo "  No bots configured."
        echo "  Run 02-install-telegram.sh to create one."
        echo ""
        return
    fi

    local running=0
    local total=0

    for conf in "$BOTS_DIR"/*.conf; do
        local name=$(basename "$conf" .conf)
        local screen_name="claude-tg-$name"

        source "$conf"
        local work_dir="${WORK_DIR:-$HOME}"
        local token="${BOT_TOKEN:-not set}"

        total=$((total + 1))

        if screen -list 2>/dev/null | grep -q "$screen_name"; then
            echo -e "  ${GREEN}●${NC} ${name} ${GREEN}[running]${NC}"
            running=$((running + 1))
        else
            echo -e "  ${RED}○${NC} ${name} ${RED}[stopped]${NC}"
        fi
        echo "    Directory: $work_dir"
        echo "    Token    : ${token:0:10}..."
        echo ""
    done

    echo -e "  ${BLUE}$running/$total bots running${NC}"
    echo ""
}

start_all() {
    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls "$BOTS_DIR"/*.conf 2>/dev/null)" ]; then
        echo "No bots configured."
        exit 0
    fi

    echo -e "${BLUE}Starting all bots...${NC}"
    for conf in "$BOTS_DIR"/*.conf; do
        [ -f "$conf" ] || continue
        start_session "$(basename "$conf" .conf)"
    done
    echo ""
    echo -e "${GREEN}All bots started.${NC}"
}

stop_all() {
    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls "$BOTS_DIR"/*.conf 2>/dev/null)" ]; then
        echo "No bots configured."
        exit 0
    fi

    echo -e "${BLUE}Stopping all bots...${NC}"
    for conf in "$BOTS_DIR"/*.conf; do
        [ -f "$conf" ] || continue
        stop_session "$(basename "$conf" .conf)"
    done
    echo ""
    echo -e "${GREEN}All bots stopped.${NC}"
}

# ── Main ──
case "${1:-}" in
    --list|-l)       list_sessions ;;
    --stop|-s)       stop_session "${2:?Usage: $0 --stop <name>}" ;;
    --stop-all)      stop_all ;;
    --start-all)     start_all ;;
    --help|-h|"")    usage ;;
    -*)              echo "Unknown: $1"; usage; exit 1 ;;
    *)               start_session "$1" ;;
esac
