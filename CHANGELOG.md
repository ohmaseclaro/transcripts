# Changelog

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
