# transcripts

[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![requires: python3](https://img.shields.io/badge/requires-python3-informational)
![platform: macOS · Linux](https://img.shields.io/badge/platform-macOS%20%C2%B7%20Linux-lightgrey)

Every AI-agent chat you have had on this machine — Claude Code, Claude Cowork, Cursor app, cursor-agent CLI — in one searchable list. Interactive TUI for humans, `--json` for scripts and agents.

```
 3h  claude·code  545caa2f  Filter behavior review        transcripts      you: the filter doesn't work…
 1d  cursor·app   9b2e1170  Retry wrapper for the API     billing       cursor: added the backoff…
 2d  claude·cwrk  0af31c92  Nightly report job            reporting        you: ship it
```

One self-contained bash script with an embedded Python core. No dependencies beyond `python3`. `fzf` is optional and unlocks the full TUI.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ohmaseclaro/transcripts/main/install.sh | sh
```

That installs `transcripts` into `~/.local/bin` and, if Claude Code or Cursor is present, the [`find-and-read-transcripts`](skill/find-and-read-transcripts/SKILL.md) agent skill — so your agent can search your own past sessions when you say *"what did we decide about X last week?"*.

Same installer, [as a gist](https://gist.github.com/ohmaseclaro/6a83daf8f8b59c5bf684db2c94db641a) if you'd rather link that:

```sh
curl -fsSL https://gist.githubusercontent.com/ohmaseclaro/6a83daf8f8b59c5bf684db2c94db641a/raw/install.sh | sh
```

Prefer to read before you pipe? [`install.sh`](install.sh) is 60 lines. Or do it by hand:

```sh
git clone https://github.com/ohmaseclaro/transcripts.git
./transcripts/transcripts --install     # symlinks into ~/.local/bin, adds it to PATH
```

Installer knobs: `TRANSCRIPTS_BIN` (install dir), `TRANSCRIPTS_REF` (branch/tag), `TRANSCRIPTS_NO_SKILL=1` (CLI only).

**Colour goes to terminals only.** Piped output is plain text, so `--tsv`, `--json`, `--details` and `--export` are safe to parse. `NO_COLOR` and `FORCE_COLOR` are both honoured.

## Privacy

This tool is entirely local. It reads the transcript stores your agents already wrote to your disk, caches parsed metadata under `~/.cache/transcripts-tui/`, and writes markdown only when you ask for `--export`. Nothing is uploaded, and there is no network code in it at all — `install.sh` is the only file that touches the network.

Your transcripts contain whatever you pasted into those chats. Treat `--export` output, and anything you share from it, accordingly.

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
transcripts -d .               # only sessions from this directory tree
```

With fzf installed:

| Key      | Action |
|----------|--------|
| type     | filter — every word must match, over title, project, id and the last message |
| `enter`  | pick — prints the transcript path and copies it to the clipboard |
| `tab`    | show/hide the transcript preview pane — matches are highlighted and shown first |
| `ctrl-f` | search *inside* the transcripts for what you typed (see [Filtering](#filtering)) |
| `ctrl-a` | cycle agent: all → claude → cursor |
| `ctrl-e` | export the highlighted transcript to `~/Downloads/*.md` |
| `ctrl-y` | copy path without leaving the list |
| `ctrl-r` | refresh the index, back to the fast filter |
| `esc`    | quit |

Without fzf you get a numbered-list fallback: type a number to open, `/words` to filter, `a` switch agent, `n`/`p` page, `s` toggle subagents, `c` toggle searching inside transcripts, `q` quit.

## Filtering

Filters combine (AND) and are applied cheapest-first: time window → `--dir` → query → `--content`. **Any filter turns off the implicit 24h window** — only an unfiltered `--list` still shows just today.

### By directory

```sh
transcripts -d .                   # every session run in this tree
transcripts -d . -a claude         # …from Claude only
transcripts -d ~/code --json       # every project under ~/code, for a script
transcripts --here                 # shorthand for -d "$PWD"
```

`--dir`/`-d` scopes to sessions whose **working directory** is that path or anywhere below it — so `-d ~/code` finds sessions from `~/code/api`, `~/code/api/internal`, and any other repo nested in there. Sibling directories that merely share a prefix (`~/code/api-gateway` vs `~/code/api`) are not included.

Both tools keep transcripts in one central store and name each project folder after the slugged working directory (`/Users/me/api` → `-Users-me-api`), which is lossy — `-` could be a separator or part of a name. So `-d` reads the working directory recorded *inside* the session, and only falls back to decoding that folder name (resolved against the real filesystem) when the session doesn't record one. `--doctor` reports how many sessions have a known directory; Cursor CLI chats started outside a project are the usual gap.

A directory that no longer exists still works — matching falls back to the stored path — you just get a warning that it's gone.

### By text

A query is split on whitespace and **every word must match** (case-insensitive substring, any order). The TUI, the table, the TSV and the JSON all agree on what a query means.

By default only cached metadata is searched — title, project, session id, and the first and last 300 characters of the session's newest message. That is instant, and it is enough when you remember roughly what a session was called or how it ended. It cannot see the middle of a conversation.

```sh
transcripts -q "oauth bug"                 # metadata only — instant
transcripts -q oauth --content --list      # also read the conversations — slow
transcripts -q oauth -c -s 7d --scan 800   # narrow the window, scan deeper
```

`--content`/`-c` opens each non-matching transcript and searches the messages themselves. Since a busy machine can hold tens of gigabytes of transcripts, it stops after `--scan` transcripts (default 300, newest first) and tells you on stderr exactly how many it skipped:

```
transcripts: --content read the 300 newest transcripts; 3030 older ones were NOT searched.
Narrow with --since/--agent/--dir, or raise --scan (default 300).
```

Narrowing first (`-d .`, `-a claude`, `-s 7d`) is almost always faster than raising `--scan`.

**You rarely need to type `--content`.** When a query matches no metadata at all, the content search runs automatically and says so on stderr — because answering "nothing found" for something sitting in the conversation is the exact failure this tool exists to avoid. Set `TRANSCRIPTS_NO_ESCALATE=1` if you want strict metadata-only behaviour.

Windows are `Nm` / `Nh` / `Nd` / `Nw` (`-s 30m`, `-s 2w`) or `all`. Anything else is rejected rather than silently ignored.

### Seeing why something matched

With a query active, the transcript view doesn't start at the newest message — it opens on the messages that actually matched, highlights every hit, and only then shows the rest of the conversation:

```
────────────────────── 3 message(s) mentioning oauth (any word), newest first ▼
▌ you · 2026-07-27T10:02:00Z
… the refresh token rotation is dropping sessions on every oauth retry …
```

A hit buried 4,000 characters into a long message gets windowed into view rather than truncated away at the top of it. This works in the fzf preview pane (including after `ctrl-f`, which keeps the query for highlighting even though the list filter is cleared), in the no-fzf fallback, and in `transcripts -q oauth --details 'REF'`.

## Non-interactive mode

```sh
transcripts --list                     # last 24h. Pretty table on a terminal, raw TSV when piped
transcripts --list --since 10d         # look-back window: Nd / Nh / Nm  (short: -s)
transcripts --full-list                # everything, no time window
transcripts --table                    # force the pretty table (even piped)
transcripts --tsv                      # force raw TSV (even on a terminal)
transcripts --json                     # one JSON object per line
transcripts --list -a cursor -q "retry wrapper" # combine with --agent / --query / --dir / --subagents
transcripts --json -q "retry wrapper" --content # search inside the transcripts too
```

Piping implies `--list`: `transcripts -d . | head` gives you TSV, not a broken TUI.

`--since`/`--full-list` imply `--list`. Value flags accept both `--flag value` and `--flag=value`.

### Columns

Table: `ID · SOURCE · UPDATED · TITLE · LAST MESSAGE HEAD · LAST MESSAGE TAIL`, with the transcript's file path under each row. Table width follows the terminal (`COLUMNS` respected), dropping the tail and id columns as it narrows.

**The path is never truncated** — it wraps across as many lines as it needs, because it is the one thing you came for. Under 88 columns the box is abandoned entirely for a per-session card, which reads far better on a narrow terminal:

```
● Filter behavior review
  claude·code · 30 Jul 17:48 · 7090a30d · transcripts
  claude: Now the boxed table — wrap the path across as many
  lines as it needs instead of clipping it:
  ⤷ ~/.claude/projects/-Users-augustoclaro-ohmaseclaro-transcripts
    /7090a30d-a9b8-484d-b74a-254ff7de0b6f.jsonl
```

TSV columns: `id, source, updated, title, last message head, last message tail, dir, path`.

JSON keys: `id, source, agent, store, updated, updated_ts, updated_iso, title, project, dir, subagent, last_role, last_message_head, last_message_tail, path, ref`.

**Head / tail semantics:** head is the start of the session's last message; tail is its actual ending — it always ends with the message's final characters (truncation cuts from the front, `…` prefix). Tail is empty only when the head cell already shows the entire message. The head carries a role prefix: `you:` for your messages, `claude:`/`cursor:` for the agent.

### Titles

The title is the real chat window name whenever one exists, resolved in priority order: `custom-title` (your manual rename, newest wins) → `ai-title` (the app's generated name) → summary records linked to the conversation → external index/store lookups → Cowork sidecar json → first user message as last resort. Big files get a bounded deep scan for mid-file title lines. `--doctor` prints how many titles came from each source (`window=…` are real chat-window names). Untitled sessions are typically headless/scheduled runs that never got named.

## Detail view & export

Every row has a stable ref (shown by `--json` as `ref`, and printed after a TUI pick):

```sh
transcripts --details 'REF'                # last messages, newest first
transcripts --details 'REF' -q oauth       # …opening on the matches, hits highlighted
transcripts --details 'REF' --json         # structured: chronological messages + match flags
transcripts --export  'REF'                # markdown into ~/Downloads
transcripts --export  'REF' -o -           # markdown to stdout
transcripts --export  'REF' -o out.md      # markdown to a path (or a directory)
```

`--details --json` gives an agent the conversation without ANSI or truncation: `{ref, type, path, id, title, updated_iso, message_count, truncated, order, match_count, messages: [{role, text, ts, matched}]}`.

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
| `TRANSCRIPTS_HOME`    | scan **only** this dir as "home" instead of `~` and every other readable account home (used by the tests) |
| `TRANSCRIPTS_NO_FZF`  | set to force the no-fzf fallback TUI |
| `TRANSCRIPTS_SCAN`    | default `--content` scan cap (default 300) |
| `TRANSCRIPTS_KV_CAP`  | max Cursor composer records read per database (default 4000) |
| `TRANSCRIPTS_NO_ESCALATE` | never auto-run the content search on a metadata miss |
| `NO_COLOR`            | never emit colour (`FORCE_COLOR` forces it back on) |
| `COLUMNS`             | table width when the terminal size can't be detected |

## Troubleshooting

- **A session shows its first message as title** — its jsonl has no `ai-title`/`custom-title`/summary line (common for scheduled/headless runs).
- **Nothing listed** — without a query the default window is 24h; try `--since 7d` or `--full-list`. Run `--doctor` to confirm the store paths exist.
- **A query finds nothing you know you discussed** — metadata search only sees titles and the newest message. Add `--content` to search the conversations themselves.
- **`--content` is slow** — it is reading transcripts off disk. Narrow with `-a claude` or `-s 7d` before raising `--scan`.
- **Stale rows after heavy use** — `rm -rf ~/.cache/transcripts-tui`.
- **Locked/huge Cursor db skipped** — if the global `state.vscdb` can't be opened read-only it is skipped rather than copied (guard at 2 GB); close Cursor and retry.

## Development

The whole tool is one file: [`transcripts`](transcripts). Bash handles arguments and the TUI; an embedded Python heredoc does the parsing, indexing and output.

```sh
./test-filter.sh     # filter behaviour, against a throwaway fixture home
bash -n transcripts  # syntax check
```

`test-filter.sh` builds a fake `~/.claude/projects` in a temp dir and points the tool at it via `TRANSCRIPTS_HOME`, so it never touches your real transcripts.

Bug reports and PRs welcome — [open an issue](https://github.com/ohmaseclaro/transcripts/issues). If you are adding a store (another agent, another editor), the scanners live next to `claude_files()` and each one just needs to produce `mkrow(...)` results.

## License

[MIT](LICENSE)
