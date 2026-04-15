#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# CLAUDE CODE TELEGRAM - Official Anthropic plugin setup
# Uses the built-in Telegram plugin from Claude Code (no custom bot)
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

AGENT_HOME="$HOME/claude-agent"
BOTS_DIR="$AGENT_HOME/bots"
SCRIPTS_DIR="$AGENT_HOME/scripts"

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   TELEGRAM SETUP - Official Anthropic Plugin                  ${NC}"
echo -e "${BLUE}   Step 2 of 2: Connect Telegram                              ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo ""

# ── Pre-checks ──
info "Running pre-checks..."

if ! command -v claude &> /dev/null; then
    err "Claude Code is not installed. Run 01-install.sh first."
    exit 1
fi

if ! command -v screen &> /dev/null; then
    err "screen is not installed. Run 01-install.sh first."
    exit 1
fi

log "Claude Code and screen detected ($(claude --version 2>/dev/null || echo 'unknown'))"

# Install Telegram plugin from source
PLUGIN_DIR="$AGENT_HOME/plugins/claude-plugins-official/external_plugins/telegram"
if [ ! -d "$PLUGIN_DIR" ]; then
    info "Downloading official Telegram plugin..."
    mkdir -p "$AGENT_HOME/plugins"
    git clone --depth 1 https://github.com/anthropics/claude-plugins-official.git \
        "$AGENT_HOME/plugins/claude-plugins-official" > /dev/null 2>&1
    if [ -d "$PLUGIN_DIR" ]; then
        log "Telegram plugin downloaded"
    else
        err "Failed to download Telegram plugin."
        err "Check your internet connection and try again."
        exit 1
    fi
else
    log "Telegram plugin already present"
fi

# Register plugin via CLI (marketplace + install)
info "Registering Telegram plugin in Claude..."
claude plugin marketplace add anthropics/claude-plugins-official > /dev/null 2>&1 || true
claude plugin install telegram@claude-plugins-official > /dev/null 2>&1 || true
log "Telegram plugin registered"

# ── Create bots directory ──
mkdir -p "$BOTS_DIR"
mkdir -p "$AGENT_HOME/logs"

# ══════════════════════════════════════════════════════════════════
# STEP-BY-STEP GUIDE: Create a Telegram bot
# ══════════════════════════════════════════════════════════════════

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Create a Telegram bot via @BotFather                        ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  If you don't have a Telegram bot yet, follow these steps:"
echo ""
echo "  1. Open Telegram on your phone or PC"
echo "  2. Search for @BotFather in the search bar"
echo "  3. Send the command: /newbot"
echo "  4. Choose a name for your bot (e.g. My Claude Agent)"
echo "  5. Choose a username (must end with _bot, e.g. myclaudeagent_bot)"
echo "  6. BotFather will give you a token that looks like:"
echo "     123456789:ABCdefGHIjklMNOpqrSTUvwxYZ"
echo ""
echo -e "  ${YELLOW}Tip: 1 bot = 1 isolated session = 1 separate context${NC}"
echo -e "  ${YELLOW}Create multiple bots to keep your projects separate!${NC}"
echo ""

read -p "  Press Enter when you have your bot token ready..."
echo ""

# ── Ask for bot token ──
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Enter your bot token                                       ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Paste the token given by @BotFather."
echo ""

read -p "  Bot token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    err "Empty token. Aborting."
    exit 1
fi

# Save token to Claude's channel config
mkdir -p "$HOME/.claude/channels/telegram"
echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > "$HOME/.claude/channels/telegram/.env"
chmod 600 "$HOME/.claude/channels/telegram/.env"
log "Bot token saved"

# ── Ask for session name ──
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Name this session                                          ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Give a short name to this session (no spaces)."
echo "  Examples: web-project, api-backend, personal-bot"
echo ""

read -p "  Session name: " SESSION_NAME_RAW

# Sanitize the name
SESSION_NAME=$(echo "$SESSION_NAME_RAW" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

if [ -z "$SESSION_NAME" ]; then
    err "Empty session name. Aborting."
    exit 1
fi

# Show sanitized name if it was changed
if [ "$SESSION_NAME" != "$SESSION_NAME_RAW" ]; then
    info "Name adjusted to: $SESSION_NAME"
fi

# Check if session already exists
if [ -f "$BOTS_DIR/$SESSION_NAME.conf" ]; then
    warn "A session named '$SESSION_NAME' already exists."
    read -p "  Overwrite configuration? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[yY]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

log "Session: $SESSION_NAME"

# ── Working directory ──
echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Working directory                                          ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Which directory should Claude work in for this session?"
echo "  (Leave empty to use $HOME)"
echo ""

read -p "  Working directory: " WORK_DIR
WORK_DIR="${WORK_DIR:-$HOME}"

# Create directory if it doesn't exist
if [ ! -d "$WORK_DIR" ]; then
    read -p "  This directory doesn't exist. Create it? (Y/n): " CREATE_DIR
    if [[ ! "$CREATE_DIR" =~ ^[nN]$ ]]; then
        mkdir -p "$WORK_DIR"
        log "Directory created: $WORK_DIR"
    else
        warn "Directory not created. You can create it later."
    fi
fi

log "Working directory: $WORK_DIR"

# ── Save configuration (with bot token for multi-bot isolation) ──
cat > "$BOTS_DIR/$SESSION_NAME.conf" << CONF_EOF
# Claude Telegram session configuration: $SESSION_NAME
# Created on $(date +%Y-%m-%d)
SESSION_NAME="$SESSION_NAME"
WORK_DIR="$WORK_DIR"
BOT_TOKEN="$BOT_TOKEN"
CONF_EOF
chmod 600 "$BOTS_DIR/$SESSION_NAME.conf"
log "Configuration saved to $BOTS_DIR/$SESSION_NAME.conf"

# ── Install multi-session management script ──
info "Installing session management script..."

SCRIPT_SOURCE="$(dirname "$0")/start-claude-telegram.sh"
if [ -f "$SCRIPT_SOURCE" ]; then
    cp "$SCRIPT_SOURCE" "$SCRIPTS_DIR/start-claude-telegram.sh"
    chmod +x "$SCRIPTS_DIR/start-claude-telegram.sh"
    log "Session management script installed"
else
    warn "start-claude-telegram.sh not found next to this script."
    warn "Make sure both files are in the same directory."
    warn "Session management commands won't work until this is fixed."
fi

# ══════════════════════════════════════════════════════════════════
# LAUNCH
# ══════════════════════════════════════════════════════════════════

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   First launch                                               ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Claude will now open in a screen session."
echo "  The Telegram plugin and bot token are pre-configured."
echo ""
echo -e "  ${BLUE}A) Sign in to Claude (first time only):${NC}"
echo "     Claude shows a URL. Open it in your browser,"
echo "     sign in with your Max account, paste the code back."
echo ""
echo -e "  ${BLUE}B) Pair with Telegram:${NC}"
echo "     1. Send any message to your bot on Telegram"
echo "     2. The bot replies with a 6-character pairing code"
echo "     3. In Claude, type: ${BLUE}/telegram:access pair THE_CODE${NC}"
echo ""
echo -e "  ${YELLOW}Once paired and working:${NC}"
echo "    -> Press Ctrl+A then D to detach (keeps it running in background)"
echo ""

read -p "  Press Enter to launch (or type N to skip): " LAUNCH

if [[ "$LAUNCH" =~ ^[nN]$ ]]; then
    echo ""
    echo "  You can launch manually later with:"
    echo -e "  ${BLUE}~/claude-agent/scripts/start-claude-telegram.sh $SESSION_NAME${NC}"
    echo ""
    echo "-- Useful commands --"
    echo ""
    echo -e "  List sessions : ${BLUE}~/claude-agent/scripts/start-claude-telegram.sh --list${NC}"
    echo -e "  Add another   : ${BLUE}./02-install-telegram.sh${NC}"
    echo ""
    exit 0
fi

# Launch session
SCREEN_NAME="claude-tg-$SESSION_NAME"

# Kill existing session if any
screen -S "$SCREEN_NAME" -X quit 2>/dev/null || true
sleep 1

echo ""
echo -e "${GREEN}  Launching Claude with Telegram plugin...${NC}"
echo -e "${GREEN}  Follow the instructions on screen.${NC}"
echo -e "${GREEN}  When done, detach with: Ctrl+A then D${NC}"
echo ""

# Launch Claude in a screen with isolated bot token via env var
# Each bot gets its own token so multiple bots can run in parallel
screen -S "$SCREEN_NAME" bash -c "cd \"$WORK_DIR\" && TELEGRAM_BOT_TOKEN=\"$BOT_TOKEN\" claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --permission-mode bypassPermissions; echo ''; echo 'Claude session ended unexpectedly.'; echo 'Possible causes:'; echo '  - Authentication expired (run: claude login or check your token)'; echo '  - Plugin not available (check your Claude Code version)'; echo '  - Network issue'; echo ''; echo 'To retry: ~/claude-agent/scripts/start-claude-telegram.sh $SESSION_NAME'; echo 'To diagnose: ~/claude-agent/scripts/doctor.sh'; echo ''; echo 'Press Enter to close.'; read"

# User is back here after detaching or session ending
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   SETUP COMPLETE!                                             ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "-- Useful commands --"
echo ""
echo -e "  Reattach  : ${BLUE}screen -r $SCREEN_NAME${NC}"
echo -e "  Start     : ${BLUE}~/claude-agent/scripts/start-claude-telegram.sh $SESSION_NAME${NC}"
echo -e "  Stop      : ${BLUE}~/claude-agent/scripts/start-claude-telegram.sh --stop $SESSION_NAME${NC}"
echo -e "  List all  : ${BLUE}~/claude-agent/scripts/start-claude-telegram.sh --list${NC}"
echo -e "  Add a bot : ${BLUE}./02-install-telegram.sh${NC}"
echo -e "  Diagnostic: ${BLUE}~/claude-agent/scripts/doctor.sh${NC}"
echo ""

# ── Auto-start on reboot ──
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Auto-start on server reboot                                ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Screen sessions are lost when the server reboots."
echo "  Want to auto-start all Telegram sessions on boot?"
echo ""

read -p "  Enable auto-start on reboot? (Y/n): " AUTOSTART

if [[ ! "$AUTOSTART" =~ ^[nN]$ ]]; then
    CRON_LINE="@reboot sleep 10 && $HOME/claude-agent/scripts/start-claude-telegram.sh --start-all >> $HOME/claude-agent/logs/reboot.log 2>&1"
    # Add to crontab without duplicating
    (crontab -l 2>/dev/null | grep -v "start-claude-telegram" ; echo "$CRON_LINE") | crontab - 2>/dev/null
    log "Auto-start on reboot enabled"
    echo -e "  Sessions will restart automatically 10 seconds after boot."
else
    echo ""
    echo "  No problem. After a reboot, restart manually with:"
    echo -e "  ${BLUE}~/claude-agent/scripts/start-claude-telegram.sh --start-all${NC}"
fi
echo ""
