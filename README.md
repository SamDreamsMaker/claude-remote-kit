# Claude Code Agent Kit - Ubuntu Server (Max Subscription)

Installation kit to run Claude Code as an autonomous agent on an Ubuntu server, with Telegram integration via the official Anthropic plugin.

**Multi-bot ready** — run as many Claude bots as you want, each with its own Telegram bot, its own project, and its own isolated context.

## Kit Contents

| File | Purpose |
|---|---|
| `01-install.sh` | Install Claude Code + dependencies + config + hooks + agent scripts |
| `02-install-telegram.sh` | Add a new Telegram bot (step-by-step, noob-friendly) |
| `start-claude-telegram.sh` | Multi-bot session manager (start, stop, list) |

## Principle: 1 bot = 1 project = 1 isolated context

Each Telegram bot runs in its own screen session with:
- Its **own Telegram bot token** (no conflict between bots)
- Its **own working directory** (separate project per bot)
- Its **own context** (no history mixing between projects)

This means you can have one bot for your web app, another for your mobile app, another for DevOps — all running in parallel on the same server.

---

## Installation (2 steps)

Connect to your Ubuntu server: `ssh your-user@SERVER-IP`

### Step 1 of 2: Install

One-liner bootstrap (downloads and runs the installer):

```bash
curl -fsSL https://raw.githubusercontent.com/SamDreamsMaker/claude-remote-kit/main/01-install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

Automatically installs: Claude Code (latest), Bun, Node.js, screen, dependencies, configuration, security hooks, and agent scripts. The full kit is cloned into `~/claude-remote-kit/`.

### Step 2 of 2: Add a Telegram bot

```bash
~/claude-remote-kit/02-install-telegram.sh
```

The script guides you step by step:
1. Create a bot via @BotFather on Telegram
2. Paste the bot token
3. Name the session (e.g. `web-project`)
4. Choose the working directory
5. Launch Claude Code in a screen session
6. Sign in with your Max account (one time only)
7. Send a message to your bot on Telegram → it replies!

**Want another bot?** Just run the same script again with a new bot token.

---

## Manage your bots

```bash
# See all bots and their status
~/claude-agent/scripts/start-claude-telegram.sh --list

# Start a specific bot
~/claude-agent/scripts/start-claude-telegram.sh my-project

# Start ALL bots at once
~/claude-agent/scripts/start-claude-telegram.sh --start-all

# Stop a bot
~/claude-agent/scripts/start-claude-telegram.sh --stop my-project

# Stop all bots
~/claude-agent/scripts/start-claude-telegram.sh --stop-all

# Attach to a bot's screen (see what it's doing)
screen -r claude-tg-my-project

# Detach (leave it running in background)
Ctrl+A then D
```

### Example: 3 bots running in parallel

```
== Claude Telegram — Bot Central ==

  ● web-app [running]
    Directory: /home/user/projects/web-app
    Token    : 123456789...

  ● mobile-api [running]
    Directory: /home/user/projects/mobile-api
    Token    : 987654321...

  ○ devops [stopped]
    Directory: /home/user/infrastructure
    Token    : 111222333...

  2/3 bots running
```

---

## Bot configuration files

Each bot has a simple config file in `~/claude-agent/bots/`:

```bash
# ~/claude-agent/bots/my-project.conf
SESSION_NAME="my-project"
WORK_DIR="/home/user/projects/my-project"
BOT_TOKEN="123456789:AAH..."
```

You can edit these files directly to change the working directory or token.

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
| Bot configurations | `~/claude-agent/bots/*.conf` |
| Logs | `~/claude-agent/logs/` |

---

## Troubleshooting

### Bot stopped responding?

1. Check status: `~/claude-agent/scripts/start-claude-telegram.sh --list`
2. Reattach: `screen -r claude-tg-<session-name>`
3. If auth expired, Claude shows a sign-in URL — follow it
4. Restart: `~/claude-agent/scripts/start-claude-telegram.sh <session-name>`
5. Diagnose: `~/claude-agent/scripts/doctor.sh`

### After server reboot?

All screen sessions are lost on reboot. Restart all bots with:
```bash
~/claude-agent/scripts/start-claude-telegram.sh --start-all
```

Or enable auto-start during the `02-install-telegram.sh` setup.
