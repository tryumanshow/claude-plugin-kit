# token-gauge

Real-time session info in the Claude Code status bar — no commands needed.

## What it shows

```
Current Model: Sonnet  │  Context: 🧠 ██████░░░░ 62%  124k/200k  │  Elapsed: 1h23m
```

| Section | Description |
|---|---|
| **Current Model** | Active model name (updates when switching Opus ↔ Sonnet) |
| **Context** | Context window usage out of 200k tokens |
| **Elapsed** | Time since current session started |

Context thresholds:

| Indicator | When |
|---|---|
| 🧠 | Normal (< 85%) |
| ⚠️ | Warning (85–94%) |
| 🚨 | Critical (≥ 95%) |

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

## How it works

Two hooks run in parallel:

| Hook | Trigger | What it does |
|---|---|---|
| **statusLine** (`combined-status.sh`) | Every ~300ms | Reads session JSONL, renders status bar |
| **UserPromptSubmit** (`show-usage.sh`) | Each user message | Calls Anthropic usage API, injects context into Claude |

### Performance

- Session file lookup is cached for 5 seconds — avoids scanning hundreds of JSONL files on every poll
- Only the first 1KB (timestamp) and last 30KB (tokens) of the session file are read per poll
- API calls happen at most once per 5 minutes via the UserPromptSubmit hook

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
│   ├── combined-status.sh   # statusLine entry point (extracts model from stdin)
│   ├── show-usage.sh        # UserPromptSubmit hook (API call + Claude context)
│   └── token-status.sh      # statusLine renderer (model, context, elapsed)
└── skills/setup/
    └── SKILL.md             # /token-gauge:setup
```

Installed to: `~/.claude/hooks/token-gauge/`
