# Plugins

Available plugins in this marketplace. Each plugin lives in its own directory with a detailed README.

---

## fork-session

Fork any Claude Code session at a chosen conversation turn into a new terminal window.

Useful when you want to explore a different direction mid-conversation without losing your current progress.

```
/fork-session:fork          # interactive arrow-key picker
/fork-session:fork 42       # fork at line 42
```

→ [Full documentation](./fork-session/README.md)

---

## token-gauge

Real-time context token usage in the Claude Code status bar — no commands needed.

Shows a live gauge (e.g. `🧠 ██████░░░░  54%  108k/200k`) in the status bar at the bottom of the terminal. Automatically wraps any existing statusLine content.

```
/token-gauge:setup          # run once after install
```

→ [Full documentation](./token-gauge/README.md)

---

## habit

Auto-detect repeated question patterns across sessions and propose Claude Code skill generation.

Runs silently in the background. When the same topic appears across 3+ different sessions, Claude offers to turn it into a reusable slash command.

```
/habit:setup                # run once after install
```

→ [Full documentation](./habit/README.md)
