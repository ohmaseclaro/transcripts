# transcripts

Unified TUI browser for every AI-agent chat transcript on this machine — Claude Code, Claude Cowork, Cursor app, and cursor-agent CLI — in one searchable list, with a non-interactive mode for scripting.

A single self-contained bash script (`transcripts`) with an embedded Python core. No dependencies beyond `python3`; `fzf` is optional but unlocks the nicer TUI.

## Layout & install

```
~/ohmaseclaro/transcripts/transcripts   # canonical copy (this repo)
~/.local/bin/transcripts                # symlink → repo copy
```

The symlink means edits to the repo copy are live immediately. To (re)create it:

```sh
~/ohmaseclaro/transcripts/transcripts --install
```

`--install` symlinks into `~/.local/bin` and adds that dir to PATH in your shell rc if missing.

## What it scans

| Source tag    | Where the data lives |
|---------------|----------------------|
| `claude·code` | `~/.claude/projects/**/*.jsonl` — Claude Code CLI + desktop-app Code sessions |
| `claude·cwrk` | same store, sessions whose cwd is a Cowork session dir, plus a direct scan of `~/Library/Application Support/Claude/local-agent-mode-sessions/**/*.jsonl` |
| `cursor·app`  | Cursor IDE chats: composer transcripts in `cursorDiskKV` of `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` **and** each `workspaceStorage/*/state.vscdb` (every composer inside each db is enumerated), plus legacy chat tabs |
| `cursor·cli`  | `~/.cursor/chats/*/*/store.db` — cursor-agent CLI sessions |
| `cursor·sub`  | Cursor subagent/background runs (composers with `subagentInfo` + `~/.cursor/projects/*/agent-transcripts/**`). Hidden unless `--subagents` |

Other readable macOS/Linux account homes on the machine are scanned too. Databases are opened read-only, so it's safe while Claude/Cursor are running. Sessions synced into multiple stores are deduped (same id → newest kept).

## Interactive TUI

```sh
transcripts                    # agent picker, then browse
transcripts -a claude          # only claude (also: cursor, all)
transcripts -q "oauth bug"     # start pre-filtered
```

With fzf installed:

| Key      | Action |
|----------|--------|
| type     | fuzzy-filter (title, last message head+tail, project, id) |
| `enter`  | pick — prints the transcript path and copies it to the clipboard |
| `tab`    | show/hide the transcript preview pane |
| `ctrl-a` | cycle agent: all → claude → cursor |
| `ctrl-e` | export the highlighted transcript to `~/Downloads/*.md` |
| `ctrl-y` | copy path without leaving the list |
| `ctrl-r` | refresh the index |
| `esc`    | quit |

Without fzf you get a numbered-list fallback: type a number to open, `/words` to filter, `a` switch agent, `n`/`p` page, `s` toggle subagents, `q` quit.

## Non-interactive mode

```sh
transcripts --list                     # last 24h. Pretty table on a terminal, raw TSV when piped
transcripts --list --since 10d         # look-back window: Nd / Nh / Nm  (short: -s)
transcripts --full-list                # everything, no time window
transcripts --table                    # force the pretty table (even piped)
transcripts --tsv                      # force raw TSV (even on a terminal)
transcripts --json                     # one JSON object per line
transcripts --list -a cursor -q kubota # combine with --agent / --query / --subagents
```

`--since`/`--full-list` imply `--list`. Value flags accept both `--flag value` and `--flag=value`.

### Columns

Table: `ID · SOURCE · UPDATED · TITLE · LAST MESSAGE HEAD · LAST MESSAGE TAIL`, with the transcript's file path on a second line under each row. Table width follows the terminal (`COLUMNS` respected).

TSV columns: `id, source, updated, title, last message head, last message tail, path`.

JSON keys: `id, source, updated, updated_ts, title, project, last_role, last_message_head, last_message_tail, path, ref`.

**Head / tail semantics:** head is the start of the session's last message; tail is its actual ending — it always ends with the message's final characters (truncation cuts from the front, `…` prefix). Tail is empty only when the head cell already shows the entire message. The head carries a role prefix: `you:` for your messages, `claude:`/`cursor:` for the agent.

### Titles

The title is the real chat window name whenever one exists, resolved in priority order: `custom-title` (your manual rename, newest wins) → `ai-title` (the app's generated name) → summary records linked to the conversation → external index/store lookups → Cowork sidecar json → first user message as last resort. Big files get a bounded deep scan for mid-file title lines. `--doctor` prints how many titles came from each source (`window=…` are real chat-window names). Untitled sessions are typically headless/scheduled runs that never got named.

## Detail view & export

Every row has a stable ref (shown by `--json` as `ref`, and printed after a TUI pick):

```sh
transcripts --details 'cc|/path/to/session.jsonl|<session-id>'   # last messages, newest first
transcripts --export  'cc|/path/to/session.jsonl|<session-id>'   # write markdown to ~/Downloads
```

Ref prefixes: `cc` claude jsonl · `cs` cursor CLI db · `ca` cursor composer · `cl` cursor legacy tab · `cj` cursor subagent jsonl. Quote refs — they contain `|`.

## Diagnostics

```sh
transcripts --doctor     # what was found where, per-source counts, title stats, parse errors
transcripts --version
transcripts --help
```

## Cache

Parsed results are cached in `~/.cache/transcripts-tui/index-v5.json`, keyed by file mtime+size — only changed files are re-parsed. Safe to delete any time; the next run rebuilds it.

## Environment variables

| Var | Effect |
|-----|--------|
| `TRANSCRIPTS_HOME`    | scan this dir as "home" instead of `~` (useful for testing with fixtures) |
| `TRANSCRIPTS_NO_FZF`  | set to force the no-fzf fallback TUI |
| `COLUMNS`             | table width when the terminal size can't be detected |

## Troubleshooting

- **A session shows its first message as title** — its jsonl has no `ai-title`/`custom-title`/summary line (common for scheduled/headless runs).
- **Nothing listed** — default window is 24h; try `--since 7d` or `--full-list`. Run `--doctor` to confirm the store paths exist.
- **Stale rows after heavy use** — `rm -rf ~/.cache/transcripts-tui`.
- **Locked/huge Cursor db skipped** — if the global `state.vscdb` can't be opened read-only it is skipped rather than copied (guard at 2 GB); close Cursor and retry.
