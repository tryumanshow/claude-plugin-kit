# claude-plugin-kit

Personal Claude Code plugin marketplace by [@tryumanshow](https://github.com/tryumanshow).

## Plugins

| Plugin | What it does | Invocation |
|---|---|---|
| **fork-session** | Fork a session at any turn into a new terminal window | `/fork-session:fork [line]` |
| **token-gauge** | Real-time context usage bar in the status bar | automatic (statusLine) |
| **habit** | Detect repeated question patterns and auto-generate skills | automatic (background) |

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
claude plugin install habit@claude-plugin-kit
```

### Step 3 — One-time setup (inside a Claude Code session)

Open a Claude Code session, then run the setup skill for each plugin you installed:

```
/token-gauge:setup
/habit:setup
```

> ⚠️ Setup skills must be run **inside a Claude Code session** (not the terminal).

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

Appears automatically in the Claude Code **status bar** after `/token-gauge:setup`:

```
[OMC] ...  │  🧠 ██████████░░░░  68%  136k/200k
```

Urgency levels:
- 🧠 **< 85%** — normal
- ⚠️ **85–94%** — warning
- 🚨 **≥ 95%** — critical

### `habit`

Runs silently in the background. No commands needed.

When the same topic appears across **3+ different sessions**, Claude will say:

```
[HABIT] 이 주제의 질문이 3개의 다른 세션에서 반복됐어요:

  • "파이썬으로 CSV 파일 파싱하는 법 알려줘"
  • "Python에서 csv 파일 읽는 방법이 뭐야"
  • "csv 파일을 파이썬으로 불러오고 싶은데"

이 패턴으로 스킬을 만들면 다음부터 slash command로 바로 쓸 수 있어요.
'스킬 만들어줘' 또는 'ok'라고 하면 지금 바로 생성할게요.
```

Reply `ok` and Claude generates a `SKILL.md` you can reuse.

Pattern DB: `~/.claude/hooks/habit/patterns.json`

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
  token-gauge/                  # Real-time token display in status bar
    .claude-plugin/plugin.json
    hooks/
      show-usage.sh             # UserPromptSubmit hook (Claude context)
      token-status.sh           # statusLine script (user-visible)
    skills/setup/
      SKILL.md                  # /token-gauge:setup
  habit/                        # Auto skill generation from repeated patterns
    .claude-plugin/plugin.json
    hooks/
      detect.sh                 # UserPromptSubmit hook (pattern detection)
    skills/setup/
      SKILL.md                  # /habit:setup
```

## Adding a new plugin

See [CONTRIBUTING.md](./CONTRIBUTING.md).
