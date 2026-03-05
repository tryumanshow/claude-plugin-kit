# claude-plugin-kit

Personal Claude Code plugin marketplace by [@tryumanshow](https://github.com/tryumanshow).

## Plugins

| Plugin | What it does | Invocation |
|---|---|---|
| **fork-session** | Fork a session at any turn into a new terminal window | `/fork-session:fork [line]` |
| **token-gauge** | Real-time context usage bar after every response | automatic (Stop hook) |

---

## Installation

### Step 1 — Add marketplace (one-time)

```bash
claude plugin marketplace add tryumanshow/claude-plugin-kit
```

### Step 2 — Install plugins

```bash
# Install what you need — pick any combination
claude plugin install fork-session@claude-plugin-kit
claude plugin install token-gauge@claude-plugin-kit
```

### Step 3 — Enable token-gauge (one-time)

Open a Claude Code session, then run:

```
/token-gauge:setup
```

> ⚠️ This must be run **inside a Claude Code session** (not the terminal).
> It writes a Stop hook into `~/.claude/settings.json`. From that point on, the gauge appears automatically after every response — no commands needed.

---

## Usage

### `fork-session`

Pick a turn interactively or pass a line number directly:

```
/fork-session:fork          # arrow-key picker (requires fzf)
/fork-session:fork 42       # forks immediately at line 42
```

**Interactive picker** (install fzf once with `brew install fzf`):

```
╭──────────────────────────────────────────────────────╮
│   👤 User    implement the auth module               │
│ ▶ 👤 User    add error handling too                  │  ← selected
│   🤖 Claude  [tool: Write]                           │
│   👤 User    looks good, now add tests               │
│                                                      │
│  ↑↓ navigate · Enter select · Esc cancel             │
╰──────────────────────────────────────────────────────╯
```

A new terminal window opens (iTerm2, Terminal, or tmux) with the forked session resumed.

### `token-gauge`

Shows automatically after every Claude response:

```
 ╭─ 🧠 Context ─────────────────────────────────────╮
 │  ████████████████████░░░░░░░░  72%               │
 │  144k used  ·  56k left  ·  200k max             │
 ╰──────────────────────────────────────────────────╯
```

Color scales with urgency:
- 🟢 **< 60%** — green
- 🟡 **60–85%** — yellow
- 🔴 **> 85%** — red + warning
- 🚨 **> 95%** — critical + `/compact` reminder

---

## Repository structure

```
.claude-plugin/
  marketplace.json              # Marketplace registry
plugins/
  fork-session/                 # Session forking
    .claude-plugin/plugin.json
    skills/fork/
      SKILL.md
      fork-session.sh
  token-gauge/                  # Real-time token display
    .claude-plugin/plugin.json
    hooks/
      show-usage.sh             # Stop hook script
    skills/setup/
      SKILL.md                  # /token-gauge:setup
```

## Adding a new plugin

See [CONTRIBUTING.md](./CONTRIBUTING.md).
