# Claude Code Agent Kit - Ubuntu Server (Max Subscription)

Installation kit to run Claude Code as an autonomous agent on an Ubuntu server, with Telegram integration via the official Anthropic plugin.

## Kit Contents

| File | Purpose |
|---|---|
| `01-install.sh` | Install Claude Code + dependencies + config + hooks + agent scripts |
| `02-install-telegram.sh` | Official Telegram plugin setup (step-by-step guide) |
| `start-claude-telegram.sh` | Telegram session manager (start, stop, list) |

## Principle: 1 bot = 1 session = 1 isolated context

Each Telegram bot runs in its own screen session with its own working directory. This allows you to:
- Keep projects separate (no context mixing)
- Reduce token consumption
- Manage each agent independently

---

## Installation (2 steps)

### Before you start: Copy files to the server

From your Windows PC:

```bash
scp 01-install.sh 02-install-telegram.sh start-claude-telegram.sh your-user@SERVER-IP:~/
```

Then connect: `ssh your-user@SERVER-IP`

### Step 1 of 2: Install

```bash
chmod +x ~/01-install.sh
~/01-install.sh
```

Automatically installs: Claude Code (latest), Bun, Node.js, screen, dependencies, configuration, security hooks, and agent scripts.

### Step 2 of 2: Connect Telegram

```bash
~/02-install-telegram.sh
```

The script guides you step by step:
1. Create a bot via @BotFather on Telegram
2. Paste the bot token
3. Name the session (e.g. `web-project`)
4. Choose the working directory
5. Launch Claude Code in a screen session
6. Sign in with your Max account (Claude shows a URL, you paste back the code)
7. Send a message to your bot on Telegram, get a pairing code, enter it in Claude

Run the script again to add more bots.

---

## Manage sessions

```bash
# View all sessions
~/claude-agent/scripts/start-claude-telegram.sh --list

# Start a session
~/claude-agent/scripts/start-claude-telegram.sh web-project

# Start all sessions
~/claude-agent/scripts/start-claude-telegram.sh --start-all

# Stop a session
~/claude-agent/scripts/start-claude-telegram.sh --stop web-project

# Stop all sessions
~/claude-agent/scripts/start-claude-telegram.sh --stop-all

# Attach to a screen
screen -r claude-tg-web-project

# Detach from a screen
Ctrl+A then D
```

---

## Agent Scripts (outside Telegram)

These scripts let you run Claude tasks from the command line:

```bash
# General purpose agent
~/claude-agent/scripts/agent-run.sh "Analyze the code" /path/to/project

# Code review
~/claude-agent/scripts/agent-review.sh my-branch main /path/to/project

# Maintenance
~/claude-agent/scripts/agent-maintenance.sh /path/to/project

# Autonomous development
~/claude-agent/scripts/agent-dev.sh "Implement JWT auth" /path/to/project

# Diagnostic
~/claude-agent/scripts/doctor.sh
```

---

## Configuration

| What | Where |
|---|---|
| Global settings | `~/.claude/settings.json` |
| Security hooks | `~/claude-agent/config/hooks/` |
| Bot configurations | `~/claude-agent/bots/` |
| Logs | `~/claude-agent/logs/` |

---

## Session Expired?

If Claude stops responding after a while:

1. Reattach to the screen: `screen -r claude-tg-<session-name>`
2. Claude will show a sign-in URL if the session expired — follow it
3. Or run `~/claude-agent/scripts/doctor.sh` to diagnose
4. Restart sessions: `~/claude-agent/scripts/start-claude-telegram.sh --start-all`
