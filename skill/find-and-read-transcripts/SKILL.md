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

This machine has a unified transcript browser: the `transcripts` CLI (usually on PATH at
`~/.local/bin/transcripts`; https://github.com/ohmaseclaro/transcripts). It indexes every local
agent conversation — Claude Code, Claude Cowork, Cursor app composers, cursor-agent CLI — with
real chat-window titles, timestamps, and the head *and* tail of each session's last message.
Use it instead of hand-globbing `~/.claude/projects` or poking at Cursor's sqlite stores: it
already knows every store location, dedupes synced copies, and resolves proper titles.

Run `transcripts --help` for the full flag list (column semantics, cache, troubleshooting).

## Workflow

### 1. Find candidate sessions

Always use machine-readable output when you are the consumer:

```sh
transcripts --json --since 7d                      # everything recent, one JSON per line
transcripts --json --since 2d -a claude            # only claude (also: cursor, all)
transcripts --json -d .                            # sessions run in THIS directory tree
transcripts --json -q "oauth bug"                  # title + last message + project + id, all time
transcripts --json -q oauth --content              # ALSO search inside the conversations
```

Each line has: `id, source, agent, store, updated, updated_ts, updated_iso, title, project,
dir, subagent, last_role, last_message_head, last_message_tail, path, ref`.

Picking the right session: `title` is the real chat-window name; `last_message_head`/`_tail`
show how the conversation started ending and how it actually ended — the tail is usually the
strongest signal of where a session left off.

**Scope by directory first — it is free and it is usually what the user means.**

`-d PATH` keeps only sessions whose working directory is PATH or anywhere below it. When the
user says "this project", "here", or "what did we do in the api repo", start with `-d`:

```sh
transcripts --json -d .                    # this tree, any agent, all time
transcripts --json -d . -a claude -s 7d    # narrower still
transcripts --json -d ~/code/api -q auth   # combine freely — filters AND together
```

Sessions whose directory was never recorded (mostly Cursor CLI chats started outside a project)
cannot match `-d`. If a `-d` search comes back empty and you expected hits, retry without it
before concluding nothing exists.

**Two search depths, and the difference matters:**

- `-q words` searches cached metadata only — title, project, id, and the first/last 300 chars of
  the session's newest message. Instant. Every word must match (case-insensitive substring), so
  prefer two or three distinctive words over a sentence.
- `-q words --content` additionally opens each non-matching transcript and searches the messages
  themselves. This is what you want for "the chat where we decided X" when X was said mid-session
  — metadata search structurally cannot find that. It is slow and stops after `--scan`
  transcripts (default 300, newest first), printing what it skipped on stderr. **Narrow before
  you deepen**: `-a claude -s 7d --content` beats `--content --scan 2000`.

A query searches all time by default. Without a query the window is 24h, so pass `--since`
when listing. Add `--subagents` if the user means a background/subagent run.

### 2. Read the transcript

Two levels, depending on how much context is needed:

```sh
transcripts --details 'REF'             # last ~14 messages, newest first — quick context
transcripts --details 'REF' --json      # STRUCTURED: every message as JSON — prefer this
transcripts --details 'REF' -q oauth    # opens on the matching messages, not the newest
transcripts --export 'REF' -o -         # full transcript as markdown on stdout
transcripts --export 'REF'              # …or written to ~/Downloads (prints the path)
```

`REF` is the `ref` field from the JSON — always single-quote it (contains `|`).

`--details --json` is the one to reach for: `{ref, type, path, id, title, updated_iso,
message_count, truncated, order, match_count, messages: [{role, text, ts, matched}]}`, in
chronological order, with no ANSI and no per-message truncation. With `-q`, `matched` tells you
exactly which messages hit the query. Use `--export 'REF' -o -` when you want the whole thing as
readable markdown in one blob instead.

Output is plain text whenever it is piped, so nothing here needs escape-code stripping.

For Claude sessions (`ref` starting `cc|`) you can also read the `path` jsonl directly for
full fidelity (every line is a JSON event; message text lives in `.message.content`). Cursor
sessions live inside sqlite databases — do NOT try to parse those yourself; `--details` /
`--export` already handle bubbles, composers, and legacy tabs.

### 3. Load the context

Summarize what matters for the user's current task: what was being worked on, decisions made,
where it left off, unfinished items. Quote exact text when the user asks what was literally
said. Include the session's `path` so the user can point other tools at it.

## Examples

**"continue where we left off"** (user is in a project directory)
→ `transcripts --json -d . -s 7d` → pick newest by `updated_ts` → `transcripts --details 'REF'
--json` → summarize state + open threads, then continue the work.

**"continue where my last billing session left off"**
→ `transcripts --json --since 3d -q billing` → pick newest by `updated_ts` → `--details 'REF'`
→ summarize state + open threads, then continue the work.

**"what did the overnight agent runs do?"**
→ `transcripts --json --since 1d` (add `--subagents` for background runs) → `--details` on
each relevant ref → report per-session outcomes.

**"find that conversation where we decided the firecrawl key strategy"**
→ `transcripts --json -q firecrawl` → nothing? the decision was mid-conversation, so metadata
search can't see it: `transcripts --json -q firecrawl --content -s 30d` (add `-d .` if it was
this project) → then `transcripts --details 'REF' -q firecrawl --json` and read the messages
flagged `matched`.

## Notes

- `transcripts -d . -a claude` is the fastest way to answer "what has been done in this repo".
- Sessions titled with a first-message snippet had no real title (typically headless/scheduled
  runs) — judge those by `project` and message columns instead.
- `transcripts --doctor` diagnoses missing stores, parse errors, and title-resolution stats.
- Stale results: `rm -rf ~/.cache/transcripts-tui` (cache rebuilds on next run).
- The interactive TUI (bare `transcripts`) is for humans; from a skill, stick to `--json` /
  `--details` / `--export`.
