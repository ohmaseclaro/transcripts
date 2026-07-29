# Changelog

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
