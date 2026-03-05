# fork-session

Fork any Claude Code session at a chosen conversation turn into a new terminal window.

## What it does

You're deep in a conversation and want to explore a different direction — without losing where you are. `fork-session` copies your session history up to a selected turn into a new session file, then opens it in a fresh terminal window.

## Install

```bash
claude plugin install fork-session@claude-plugin-kit
```

## Usage

```
/fork-session:fork          # interactive arrow-key picker
/fork-session:fork 42       # fork directly at line 42
```

### Interactive picker (recommended)

Requires [`fzf`](https://github.com/junegunn/fzf):

```bash
brew install fzf
```

When you run `/fork-session:fork`, an interactive picker opens:

```
╭──────────────────────────────────────────────────────────────╮
│   👤 User    implement the auth module                       │
│ ▶ 👤 User    add error handling too                          │  ← cursor
│   🤖 Claude  [tool: Write → auth.ts]                        │
│   👤 User    looks good, now add tests                       │
│                                                              │
│  ↑↓ navigate · Enter select · Esc cancel                     │
╰──────────────────────────────────────────────────────────────╯
```

Select the turn you want to fork **up to**, press Enter. A new terminal window opens with that session resumed.

### Without fzf

A numbered list of turns is printed. Type the number and press Enter.

## How it works

1. Reads your current session JSONL (`~/.claude/projects/.../SESSION_ID.jsonl`)
2. Copies all messages up to the selected turn into a new JSONL file
3. Opens a new terminal window (`iTerm2` → `Terminal.app` → `tmux`, whichever is available) and resumes the forked session with `claude --resume`

## Files

```
plugins/fork-session/
├── .claude-plugin/plugin.json
└── skills/fork/
    ├── SKILL.md            # skill definition (/fork-session:fork)
    └── fork-session.sh     # core script
```
