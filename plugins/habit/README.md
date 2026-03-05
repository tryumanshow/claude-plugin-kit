# habit

Auto-detect repeated prompt patterns across sessions and propose Claude Code skill generation.

## What it does

You keep asking Claude variations of the same question across different sessions. `habit` notices that, and when the same topic has come up 3+ times, Claude offers to turn it into a reusable slash command skill — so you never have to re-explain it again.

## Install

```bash
claude plugin install habit@claude-plugin-kit
```

Then run the setup skill once inside a Claude Code session:

```
/habit:setup
```

After that, it runs completely silently in the background.

## How it works

### 1. Detection (UserPromptSubmit hook)

Every prompt you send is compared against a local pattern database using [Jaccard similarity](https://en.wikipedia.org/wiki/Jaccard_index) on normalized word sets:

- Korean tech terms are normalized: `파이썬 → python`, `파싱하는/읽는/불러오는 → read`, etc.
- Noise is filtered out: prompts < 4 words, context-dependent phrases (`이거`, `지금`, `방금`, ...), skill-acceptance replies
- Threshold: **0.25** similarity score

### 2. Cross-session tracking

Each match is tagged with the current `CLAUDE_SESSION_ID`. A pattern only increments when seen from a **different** session — repetition within a single session doesn't count.

### 3. Suggestion

When a pattern has been matched across **3 or more different sessions**, Claude receives an `additionalContext` message:

```
[HABIT] 이 주제의 질문이 3개의 다른 세션에서 반복됐어요:

  • "파이썬으로 CSV 파일 파싱하는 법 알려줘"
  • "Python에서 csv 파일 읽는 방법이 뭐야"
  • "csv 파일을 파이썬으로 불러오고 싶은데"

이 패턴으로 스킬을 만들면 다음부터 slash command로 바로 쓸 수 있어요.
'스킬 만들어줘' 또는 'ok'라고 하면 지금 바로 생성할게요.
```

### 4. Skill generation

Reply `ok` (or `스킬 만들어줘`) and Claude writes a `SKILL.md` to:

```
~/.claude/hooks/habit/skills/<skill-name>/SKILL.md
```

Restart Claude Code for the new skill to be available as a slash command.

## Pattern database

Stored at `~/.claude/hooks/habit/patterns.json`. View it anytime:

```bash
cat ~/.claude/hooks/habit/patterns.json | python3 -m json.tool
```

Capped at 300 entries (oldest low-count patterns pruned automatically).

## Limitations

- Similarity is lexical (Jaccard), not semantic — very different phrasing of the same idea may not match
- Korean morphological particles (`으로`, `에서`, `이/가`) are not stripped, so `파이썬으로` ≠ `파이썬` in matching (mitigated by shared content words like filenames, tool names)
- Generated skills require a Claude Code restart to activate

## Files

```
plugins/habit/
├── .claude-plugin/plugin.json
├── hooks/
│   └── detect.sh           # UserPromptSubmit hook (pattern detection engine)
└── skills/setup/
    └── SKILL.md            # /habit:setup
```

Installed to: `~/.claude/hooks/habit/`
