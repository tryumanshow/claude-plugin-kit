# token-gauge

Real-time context token usage in the Claude Code status bar — no commands needed.

## What it does

Claude Code has a 200k token context window. As a session grows (long conversations, large files, prompt caching), that window fills up. `token-gauge` shows you exactly where you stand, always visible in the status bar at the bottom of the terminal.

```
[OMC] ...  │  🧠 ██████████░░░░  68%  136k/200k
```

## Install

```bash
claude plugin install token-gauge@claude-plugin-kit
```

Then run the setup skill once inside a Claude Code session:

```
/token-gauge:setup
```

> ⚠️ Must be run inside a Claude Code session (not the terminal).

After setup, restart Claude Code once for the status bar change to take effect.

## Display

The gauge appears in the status bar and updates automatically:

| Indicator | When |
|---|---|
| 🧠 `████████░░░░░░` | Normal (< 85%) |
| ⚠️ `████████████░░` | Warning (85–94%) |
| 🚨 `██████████████` | Critical (≥ 95%) |

Format: `ICON BAR PCT%  USED_k/200k`

## How it works

Two mechanisms run in parallel:

| Mechanism | What it does | Visible to |
|---|---|---|
| **statusLine** (`combined-status.sh`) | Reads last ~30KB of session JSONL, outputs gauge to status bar | You |
| **UserPromptSubmit hook** (`show-usage.sh`) | Injects token count as system context | Claude |

The setup skill wraps your existing statusLine (e.g. OMC HUD) and appends the gauge — existing status bar content is preserved.

### Token counting

Reads the last assistant message's `usage` fields from the session JSONL:

```
total = input_tokens + cache_read_input_tokens + cache_creation_input_tokens
```

Prompt caching splits tokens across three fields; summing all three gives the true context size.

## Files

```
plugins/token-gauge/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── show-usage.sh       # UserPromptSubmit hook (Claude context injection)
│   └── token-status.sh     # statusLine script (user-visible gauge)
└── skills/setup/
    └── SKILL.md            # /token-gauge:setup
```

Installed to: `~/.claude/hooks/token-gauge/`
