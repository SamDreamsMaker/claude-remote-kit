#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# Claude Code Telegram session manager (official plugin)
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

usage() {
    echo ""
    echo "Usage:"
    echo "  $0 <session-name>      Start (or restart) a session"
    echo "  $0 --list              List all configured sessions"
    echo "  $0 --start-all         Start all configured sessions"
    echo "  $0 --stop <name>       Stop a session"
    echo "  $0 --stop-all          Stop all sessions"
    echo ""
    echo "Examples:"
    echo "  $0 web-project         Start the 'web-project' session"
    echo "  $0 --list              Show status of all sessions"
    echo ""
}

# Start a session
start_session() {
    local SESSION_NAME="$1"
    local CONF_FILE="$BOTS_DIR/$SESSION_NAME.conf"
    local SCREEN_NAME="claude-tg-$SESSION_NAME"

    if [ ! -f "$CONF_FILE" ]; then
        echo -e "${RED}[ERR]${NC} No configuration found for '$SESSION_NAME'"
        echo "  Expected file: $CONF_FILE"
        echo "  Run 02-install-telegram.sh to create a session."
        exit 1
    fi

    # Load configuration
    source "$CONF_FILE"
    WORK_DIR="${WORK_DIR:-$HOME}"

    # Check if already running
    if screen -list 2>/dev/null | grep -q "$SCREEN_NAME"; then
        echo -e "${YELLOW}[!!]${NC} Session '$SCREEN_NAME' is already running."
        echo "  Attach : screen -r $SCREEN_NAME"
        echo "  Restart: $0 --stop $SESSION_NAME && $0 $SESSION_NAME"
        return 0
    fi

    # Create working directory if needed
    mkdir -p "$WORK_DIR" 2>/dev/null || true

    # Launch Claude with the official Telegram plugin in a screen
    screen -dmS "$SCREEN_NAME" bash -c "cd \"$WORK_DIR\" && claude --channels plugin:telegram@claude-plugins-official"

    sleep 1

    if screen -list 2>/dev/null | grep -q "$SCREEN_NAME"; then
        echo -e "${GREEN}[OK]${NC} Session '$SCREEN_NAME' started"
        echo "  Directory: $WORK_DIR"
        echo "  Attach   : screen -r $SCREEN_NAME"
        echo "  Detach   : Ctrl+A then D"
    else
        echo -e "${RED}[ERR]${NC} Failed to start session '$SCREEN_NAME'"
        exit 1
    fi
}

# Stop a session
stop_session() {
    local SESSION_NAME="$1"
    local SCREEN_NAME="claude-tg-$SESSION_NAME"

    if screen -list 2>/dev/null | grep -q "$SCREEN_NAME"; then
        screen -S "$SCREEN_NAME" -X quit
        echo -e "${GREEN}[OK]${NC} Session '$SCREEN_NAME' stopped"
    else
        echo -e "${YELLOW}[!!]${NC} Session '$SCREEN_NAME' not found (already stopped?)"
    fi
}

# List sessions
list_sessions() {
    echo ""
    echo -e "${BLUE}== Configured Claude Telegram sessions ==${NC}"
    echo ""

    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls "$BOTS_DIR"/*.conf 2>/dev/null)" ]; then
        echo "  No sessions configured."
        echo "  Run 02-install-telegram.sh to create one."
        echo ""
        return
    fi

    for conf in "$BOTS_DIR"/*.conf; do
        local name=$(basename "$conf" .conf)
        local screen_name="claude-tg-$name"

        # Load config
        local work_dir=""
        source "$conf"
        work_dir="${WORK_DIR:-$HOME}"

        # Check if screen is running
        if screen -list 2>/dev/null | grep -q "$screen_name"; then
            echo -e "  ${GREEN}●${NC} $name (running)"
        else
            echo -e "  ${RED}○${NC} $name (stopped)"
        fi
        echo "    Directory: $work_dir"
        echo "    Screen   : $screen_name"
        echo ""
    done
}

# Start all sessions
start_all() {
    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls "$BOTS_DIR"/*.conf 2>/dev/null)" ]; then
        echo "No sessions configured."
        exit 0
    fi

    for conf in "$BOTS_DIR"/*.conf; do
        local name=$(basename "$conf" .conf)
        start_session "$name"
    done
}

# Stop all sessions
stop_all() {
    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls "$BOTS_DIR"/*.conf 2>/dev/null)" ]; then
        echo "No sessions configured."
        exit 0
    fi

    for conf in "$BOTS_DIR"/*.conf; do
        local name=$(basename "$conf" .conf)
        stop_session "$name"
    done
}

# ── Main ──
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

case "$1" in
    --list|-l)
        list_sessions
        ;;
    --stop|-s)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 --stop <session-name>"
            exit 1
        fi
        stop_session "$2"
        ;;
    --stop-all)
        stop_all
        ;;
    --start-all)
        start_all
        ;;
    --help|-h)
        usage
        ;;
    -*)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    *)
        start_session "$1"
        ;;
esac
