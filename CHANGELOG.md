# Changelog

## 1.14.0

**Typing in the TUI now finds text that only exists inside a conversation.**

1.13.0 auto-escalated to a content search on the command line, but the interactive filter still
matched cached metadata only — type a string that appears solely in a thread and the list went
empty. Now:

- fzf's `zero` event fires the content search automatically when your typing runs out of
  metadata matches, debounced so it only runs once you pause rather than on every keystroke.
- Rows matched on their body carry the query terms in the hidden haystack, so fzf's own filter
  keeps showing them — without that they'd be found and then immediately hidden again.
- Those rows are flagged with `⌕` so it's clear the match came from the conversation.
- An empty result now emits one placeholder row instead of nothing, which also stops `zero`
  from re-firing the deep search in a loop. It carries no ref, and picking it exits cleanly.
- `ctrl-f` still forces the deep search when metadata already matched, and no longer clears
  your query.

## 1.13.0

**A query that matches nothing now searches the conversations by itself.**

- `transcripts -q "20260802110000-seed" -d .` used to come back empty whenever the string only
  appeared *inside* a conversation — the exact false negative `--content` exists to prevent, but
  you had to already know to ask for it. When a query matches no metadata at all, the content
  search now runs automatically and says so on stderr. `TRANSCRIPTS_NO_ESCALATE=1` restores
  strict behaviour.
- Content search got ~4× faster (10.2s → 2.5s on a real query): a raw byte scan now rejects
  files without parsing a line of JSON, and only survivors are parsed to confirm the hit is in a
  real message rather than a tool result.
- **The fzf preview crashed on an empty list** with `could not parse ref: not enough values to
  unpack (expected 3, got 1)`, because fzf renders the preview even with nothing selected. That
  pane now explains why the list is empty and which key to press.

## 1.12.0

**The transcript path is never truncated again.**

- The path under each table row used to be clipped to fit inside the box (`⤷ …laro-transcripts/
  7090a30d-….jsonl`), which is backwards — it is the most useful thing in the row. It now wraps
  across as many lines as it needs, at any width, with the box staying flush.
- Terminals under 88 columns get a **card layout** instead of a boxed table. At 66 columns the
  old table squeezed every column into ellipses; the card gives each session a title line, a
  metadata line, the last message, and the complete path.
- The header line wraps instead of overflowing, and the stale "full paths: --tsv or pipe" hint
  is gone — the paths are already full.
- The boxed table now keeps the id column down to 100 columns and the tail column down to 118,
  rather than cramming six columns into a width that can't hold them.

## 1.11.0

**A directory filter, and a review pass over everything else.**

### `--dir` / `-d`

`transcripts -d . -a claude` lists every Claude session run in this directory tree, wherever the
transcript itself is stored. `-d ~/code` covers every project underneath, `--here` is shorthand
for `$PWD`, and prefix-sharing siblings (`api` vs `api-gateway`) stay out. It matches on the
working directory recorded inside each session, falling back to decoding the slugged project
folder name (`/Users/me/api` → `-Users-me-api`) against the real filesystem when a session
doesn't record one — including for directories that have since been deleted. `--doctor` now
reports how many sessions have a resolvable directory.

### Bugs

- **`--content` only ever searched the last 2 MB of a Claude session.** Anything earlier in a
  long conversation was unfindable; it now reads the whole file.
- **Colour was emitted into pipes.** `--details`, `--table` and the highlight escapes all leaked
  ANSI into redirected output, so anything parsing it got escape codes. Colour is now terminal-
  only, honouring `NO_COLOR` / `FORCE_COLOR`.
- **A piped run with no explicit mode printed nothing at all** — it launched fzf, which failed
  invisibly against a pipe. Piping now implies `--list`.
- **Emoji and CJK broke every column to their right**: padding counted characters, not display
  width.
- **`--details REF -q term` only highlighted when `-q` came first**, because actions ran during
  argument parsing. Actions now run after the whole command line is read.
- **Highlighting reset the surrounding style**, so the rest of a matched title lost its colour.
- **Cursor databases were reopened — and, when Cursor held the lock, re-copied — once per row**
  under `--content`. Connections are now pooled (measured 1.8× faster with Cursor closed; far
  more when it is running), and composer bubbles are fetched in one range scan instead of one
  query each.
- **More than 1000 Cursor composers in a database were silently dropped.** The cap is now 4000,
  configurable via `TRANSCRIPTS_KV_CAP`, and exceeding it is reported instead of hidden.
- A composer with no usable timestamp sorted as 1970; it now falls back to the store's mtime.
- Store read errors were swallowed everywhere except `--doctor`; results that may be incomplete
  now say so on stderr.
- `--scan` with a non-numeric value silently became 300; it is now an error.
- A `|` in a transcript path corrupted the parsed ref.
- The fzf prompt kept showing the old agent after `ctrl-a` (now re-rendered, on fzf ≥ 0.45).
- Narrow terminals got a 110-column table that wrapped into noise; columns are now dropped to
  fit.

### For agents

- `--details 'REF' --json` — the conversation as structured data: chronological messages with
  `role`, `text`, `ts` and a per-message `matched` flag, plus `message_count` / `truncated`.
- `--export 'REF' -o -` writes markdown to stdout; `-o PATH` writes where you choose.
- `--json` gains `agent`, `store`, `updated_iso`, `dir` and `subagent`, and no longer truncates
  the cached message head/tail. `--tsv` gains a `dir` column before `path`.
- `--since` accepts weeks (`2w`).
- "nothing matched" now names the filter that emptied the result instead of always blaming the
  time window.

## 1.10.0

**See why a session matched, without scrolling for it.**

- Query terms are **highlighted** everywhere the transcript is rendered: the fzf preview pane,
  the no-fzf detail view, and `transcripts -q term --details 'REF'`.
- The view **opens on the matches, not the newest message.** With a query, matching messages are
  listed first (newest first), then the rest of the conversation. It also looks past the last 14
  messages, so a `--content` hit from the middle of a long session is actually visible.
- A hit buried deep inside a single long message is **windowed into view** instead of being
  truncated away by the 700-character message cap.
- `ctrl-f` clears fzf's query so content-only matches can show — the query is now kept in the
  session state file so the preview still knows what to highlight. `ctrl-r`/`ctrl-a` clear it.

## 1.9.0

**One filter everywhere, plus optional search inside transcripts.**

The query behaved three different ways depending on how you reached it:

- The fzf TUI never used the query engine at all — it was passed an empty query and fzf
  fuzzy-matched only the *rendered* line, so anything past the 44/16/110-character column
  truncation could not be matched.
- `--list`/`--table`/`--json` used one literal substring over the cached fields, so the
  documented multi-word query (`/oauth bug`) only matched that exact adjacent string.
- `--list` silently defaulted to a 24-hour window, applied *before* the query, so searching for
  an older session reported nothing found.

Now:

- **One matcher.** A query is split on whitespace and every word must appear (case-insensitive
  substring), in the TUI, the table, the TSV and the JSON alike.
- **The TUI searches everything the cache knows**, not just what fits the columns — the full
  text rides along as a trailing field that fzf matches (`--with-nth=2.. --exact --no-hscroll`).
  Matching is exact rather than fuzzy: over a longer haystack, fuzzy matched almost anything.
- **A query means "look everywhere."** `-q` implies `--since all` unless `--since` says otherwise.
- **`--content` / `-c` searches the conversations themselves**, not just cached metadata. It opens
  each non-matching transcript and reads the messages. Bounded by `--scan` (default 300, newest
  first) and reported on stderr — it never silently truncates. `ctrl-f` runs it on what you typed
  in the TUI; `c` toggles it in the no-fzf fallback.
- `TRANSCRIPTS_HOME` now means *only* that home. It previously still scanned every readable
  `/Users/*`, which made fixture-based testing impossible.
- `test-filter.sh` covers all of the above against a throwaway fixture home.

## 1.8.0

- Repo layout + README.
- Head **and** tail columns for each session's last message: the tail always shows how the
  conversation actually ended.
- Real chat-window titles (`custom-title` → `ai-title` → summary → index lookups → Cowork
  sidecar → first user message), with `--doctor` reporting where each title came from.
- Full enumeration of every composer inside each Cursor `state.vscdb`.
