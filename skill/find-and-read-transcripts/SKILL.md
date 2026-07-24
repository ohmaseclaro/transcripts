---
name: find-and-read-transcripts
description: >
  Find and read past AI-agent conversation transcripts on this machine (Claude Code, Claude
  Cowork, Cursor app, cursor-agent CLI) using the `transcripts` CLI, then load their content as
  context. Use this whenever the user refers to a previous conversation or session — "what did
  we discuss", "find the chat where...", "continue where I/we left off", "recover the context
  from", "what was that session about", "read that transcript", "load the conversation about X",
  "what did the other agent do" — or asks to search, list, summarize, or resume any past Claude
  or Cursor conversation, even if they don't say the word "transcript".
---

# Find and read transcripts

This machine has a unified transcript browser: the `transcripts` CLI (repo:
`~/ohmaseclaro/transcripts/`, on PATH via `~/.local/bin/transcripts`). It indexes every local
agent conversation — Claude Code, Claude Cowork, Cursor app composers, cursor-agent CLI — with
real chat-window titles, timestamps, and the head *and* tail of each session's last message.
Use it instead of hand-globbing `~/.claude/projects` or poking at Cursor's sqlite stores: it
already knows every store location, dedupes synced copies, and resolves proper titles.

Full documentation: `~/ohmaseclaro/transcripts/README.md` — read it if you need details beyond
this page (all flags, column semantics, cache, troubleshooting).

## Workflow

### 1. Find candidate sessions

Always use machine-readable output when you are the consumer:

```sh
transcripts --json --since 7d                      # everything recent, one JSON per line
transcripts --json --since 2d -a claude            # only claude (also: cursor, all)
transcripts --json --full-list -q "oauth bug"      # keyword search over title + last message + project
```

Each line has: `id, source, updated, updated_ts, title, project, last_role,
last_message_head, last_message_tail, path, ref`.

Picking the right session: `title` is the real chat-window name; `last_message_head`/`_tail`
show how the conversation started ending and how it actually ended — the tail is usually the
strongest signal of where a session left off. Filter with `-q` (matches title, both message
columns, project, and id). Default window is 24h — widen with `--since 7d`/`--since 30d` or
`--full-list` when the user refers to something older. Add `--subagents` if they mean a
background/subagent run.

### 2. Read the transcript

Two levels, depending on how much context is needed:

```sh
transcripts --details 'REF'      # last ~14 messages, newest first — quick context recovery
transcripts --export 'REF'       # full transcript → markdown file in ~/Downloads (prints path)
```

`REF` is the `ref` field from the JSON — always single-quote it (contains `|`).

For Claude sessions (`ref` starting `cc|`) you can also read the `path` jsonl directly for
full fidelity (every line is a JSON event; message text lives in `.message.content`). Cursor
sessions live inside sqlite databases — do NOT try to parse those yourself; `--details` /
`--export` already handle bubbles, composers, and legacy tabs.

### 3. Load the context

Summarize what matters for the user's current task: what was being worked on, decisions made,
where it left off, unfinished items. Quote exact text when the user asks what was literally
said. Include the session's `path` so the user can point other tools at it.

## Examples

**"continue where my last lathex session left off"**
→ `transcripts --json --since 3d -q lathex` → pick newest by `updated_ts` → `--details 'REF'`
→ summarize state + open threads, then continue the work.

**"what did the overnight agent runs do?"**
→ `transcripts --json --since 1d` (add `--subagents` for background runs) → `--details` on
each relevant ref → report per-session outcomes.

**"find that conversation where we decided the firecrawl key strategy"**
→ `transcripts --json --full-list -q firecrawl` → if too many/few hits, vary keywords
(`-q "api key"`) or widen/narrow `--since` → `--export 'REF'` and search the markdown for the
decision.

## Notes

- Sessions titled with a first-message snippet had no real title (typically headless/scheduled
  runs) — judge those by `project` and message columns instead.
- `transcripts --doctor` diagnoses missing stores, parse errors, and title-resolution stats.
- Stale results: `rm -rf ~/.cache/transcripts-tui` (cache rebuilds on next run).
- The interactive TUI (bare `transcripts`) is for humans; from a skill, stick to `--json` /
  `--details` / `--export`.
