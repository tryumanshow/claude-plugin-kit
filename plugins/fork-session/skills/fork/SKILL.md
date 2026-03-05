---
description: Fork the current Claude Code session at a specific conversation turn into a new terminal window. Usage: /fork [line-number]
allowed-tools: Bash
---

Fork the current Claude Code session, preserving conversation history up to a chosen point.

Current session ID: ${CLAUDE_SESSION_ID}

Run this exact command and show all output to the user:

```bash
bash "${CLAUDE_SKILL_DIR}/fork-session.sh" "${CLAUDE_SESSION_ID}" $ARGUMENTS
```

After the script finishes, tell the user the new session UUID.
