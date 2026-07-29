#!/usr/bin/env bash
# Filter behaviour check. Builds a throwaway ~/.claude/projects fixture, points the tool at it
# with TRANSCRIPTS_HOME, and asserts what the query is supposed to match.
#   ./test-filter.sh
set -u
cd "$(dirname "$0")"
TR="$PWD/transcripts"

HOME_DIR="$(mktemp -d)"
trap 'rm -rf "$HOME_DIR"' EXIT
PROJ="$HOME_DIR/.claude/projects/-Users-nobody-demo"
mkdir -p "$PROJ"

# msg FILE ROLE TEXT TIMESTAMP
msg() {
  python3 -c 'import json,sys
print(json.dumps({"type": sys.argv[2], "timestamp": sys.argv[4], "cwd": "/Users/nobody/demo",
                  "message": {"role": sys.argv[2], "content": sys.argv[3]}}))' "$@" >> "$1"
}

# recent session: the needle is buried mid-conversation, the last message is about something else
R="$PROJ/aaaaaaaa-1111-2222-3333-444444444444.jsonl"
msg "$R" user "morning, picking up the auth work" "2026-07-27T10:00:00Z"
msg "$R" assistant "sure, where do you want to start" "2026-07-27T10:01:00Z"
msg "$R" user "the refresh token rotation is dropping sessions" "2026-07-27T10:02:00Z"
for i in $(seq 1 40); do
  msg "$R" user "unrelated filler message number $i padding this out past three hundred characters so the cached head and tail cannot possibly contain the needle we are looking for in this test case here" "2026-07-27T11:00:00Z"
done
# one very long message with the needle ~900 chars in: the detail view must window to it,
# not show the first 700 chars and cut the match off
LONG="$(python3 -c 'print("MSGSTART " + "preamble text that goes on and on " * 28 + " the PINEAPPLE decision was made here " + "trailing chatter " * 40)')"
msg "$R" user "$LONG" "2026-07-27T11:30:00Z"
msg "$R" user "thanks, ship it" "2026-07-27T12:00:00Z"
touch -t 202607271200 "$R"

# old session (well outside 24h): needle IS in the last message
O="$PROJ/bbbbbbbb-5555-6666-7777-888888888888.jsonl"
msg "$O" user "quick question about the widget layout" "2026-01-02T09:00:00Z"
msg "$O" assistant "the widget grid collapses under 600px" "2026-01-02T09:01:00Z"
touch -t 202601020901 "$O"

run() { TRANSCRIPTS_HOME="$HOME_DIR" "$TR" "$@" 2>/dev/null; }

PASS=0 FAIL=0
ok() { # ok LABEL EXPECT_MATCH_COUNT ACTUAL
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL + 1)); printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$3"; fi
}
count() { printf '%s' "$1" | grep -c . || true; }

echo "filter checks (fixture home: $HOME_DIR)"

# 1. an old row is found without an explicit --since: a query means "look everywhere"
ok "query drops the implicit 24h window" 1 \
   "$(count "$(run --tsv -q widget)")"

# 2. multi-word query is AND over words, not one literal substring
ok "multi-word AND matches across fields" 1 \
   "$(count "$(run --tsv -q "widget layout")")"
ok "multi-word AND matches out of order" 1 \
   "$(count "$(run --tsv -q "layout widget")")"
ok "multi-word AND rejects a missing word" 0 \
   "$(count "$(run --tsv -q "widget banana")")"

# 3. metadata search cannot see mid-conversation text; --content can
ok "buried needle invisible to metadata search" 0 \
   "$(count "$(run --tsv -q "rotation")")"
ok "buried needle found with --content" 1 \
   "$(count "$(run --tsv -q "rotation" --content)")"
ok "--content still AND-matches" 0 \
   "$(count "$(run --tsv -q "rotation banana" --content)")"

# 4. --scan cap is reported, never silent
CAPPED="$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" --tsv -q rotation --content --scan 1 2>&1 >/dev/null)"
case "$CAPPED" in
  *"were NOT searched"*) PASS=$((PASS + 1)); echo "  ok   --scan cap is reported on stderr" ;;
  *) FAIL=$((FAIL + 1)); echo "  FAIL --scan cap not reported (got: ${CAPPED:-<nothing>})" ;;
esac

# 5. the TUI index and the list share one filter: same query, same row count
ok "index and list agree on the same query" \
   "$(count "$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __index all "widget layout" 0 2>/dev/null)")" \
   "$(count "$(run --tsv -q "widget layout")")"

# 6. what the TUI can match: fzf sees fields 2.., so the trailing haystack must be searchable
#    and must sit past the right edge (col >= 200) so it never shows up on screen.
IDX="$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __index all "" 0 2>/dev/null)"
ok "index emits ref + display + haystack" 3 "$(printf '%s' "$IDX" | head -1 | awk -F'\t' '{print NF}')"
DISP_COLS="$(printf '%s' "$IDX" | head -1 | cut -f2 | perl -pe 's/\e\[[0-9;]*m//g' | tr -d '\n' | wc -c | tr -d ' ')"
if [ "$DISP_COLS" -ge 200 ]; then PASS=$((PASS + 1)); echo "  ok   display field pads past the right edge ($DISP_COLS cols)"
else FAIL=$((FAIL + 1)); echo "  FAIL display field too short ($DISP_COLS cols) — haystack would be visible"; fi

if command -v fzf >/dev/null 2>&1; then
  FZF_OPTS="--ansi --delimiter=\t --with-nth=2.. --no-hscroll --exact"
  # shellcheck disable=SC2086
  HITS="$(printf '%s\n' "$IDX" | fzf $FZF_OPTS -f "widget layout" | wc -l | tr -d ' ')"
  ok "fzf matches the trailing haystack" 1 "$HITS"
  # exact mode matters: fuzzy would match 'rotation' as a subsequence of unrelated lines
  # shellcheck disable=SC2086
  HITS="$(printf '%s\n' "$IDX" | fzf $FZF_OPTS -f "rotation" | wc -l | tr -d ' ')"
  ok "fzf --exact does not fuzzy-match unrelated rows" 0 "$HITS"
else
  echo "  skip fzf matching check (fzf not installed)"
fi

# 7. detail view: highlight the terms, and lead with the matches instead of the newest message
REF="cc|$R|aaaaaaaa-1111-2222-3333-444444444444"
HL_ON=$'\033[30;43m'
has() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

D_PLAIN="$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __details "$REF" 2>/dev/null)"
D_HL="$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __details "$REF" "rotation" 2>/dev/null)"

if has "$HL_ON" "$D_HL"; then PASS=$((PASS + 1)); echo "  ok   details highlights the query"
else FAIL=$((FAIL + 1)); echo "  FAIL details did not highlight the query"; fi

if has "$HL_ON" "$D_PLAIN"; then FAIL=$((FAIL + 1)); echo "  FAIL details highlights with no query"
else PASS=$((PASS + 1)); echo "  ok   details stays plain with no query"; fi

if has "mentioning" "$D_HL" && has "rest of the conversation" "$D_HL"; then
  PASS=$((PASS + 1)); echo "  ok   details leads with a matches section"
else FAIL=$((FAIL + 1)); echo "  FAIL details has no matches section"; fi

# the matching message must appear before the newest message, not after it
POS_MATCH="$(printf '%s' "$D_HL" | grep -n "dropping sessions" | head -1 | cut -d: -f1)"
POS_NEWEST="$(printf '%s' "$D_HL" | grep -n "thanks, ship it" | head -1 | cut -d: -f1)"
if [ -n "$POS_MATCH" ] && [ -n "$POS_NEWEST" ] && [ "$POS_MATCH" -lt "$POS_NEWEST" ]; then
  PASS=$((PASS + 1)); echo "  ok   match is shown above the newest message"
else FAIL=$((FAIL + 1)); echo "  FAIL match not surfaced above the newest message ($POS_MATCH vs $POS_NEWEST)"; fi

# 8. a match ~900 chars into a message must be windowed into view, not truncated away at 700
D_DEEP="$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __details "$REF" "pineapple" 2>/dev/null)"
if has "PINEAPPLE" "$D_DEEP"; then PASS=$((PASS + 1)); echo "  ok   deep match is windowed into view"
else FAIL=$((FAIL + 1)); echo "  FAIL deep match cut off by the 700-char head"; fi
if has "MSGSTART" "$D_DEEP"; then
  FAIL=$((FAIL + 1)); echo "  FAIL deep match still rendered from the top of the message"
else PASS=$((PASS + 1)); echo "  ok   deep match window starts near the match, not the top"; fi

# 9. the sticky query survives ctrl-f clearing fzf's own query
ST="$HOME_DIR/state"; printf 'all\n' > "$ST"
TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __reload "$ST" 0 "pineapple" content >/dev/null 2>&1
ok "ctrl-f stores the sticky query" "pineapple" "$(sed -n 2p "$ST")"
D_STICKY="$(TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __details "$REF" "" "$ST" 2>/dev/null)"
if has "$HL_ON" "$D_STICKY"; then PASS=$((PASS + 1)); echo "  ok   preview highlights from the sticky query"
else FAIL=$((FAIL + 1)); echo "  FAIL sticky query not used by the preview"; fi
TRANSCRIPTS_HOME="$HOME_DIR" "$TR" __reload "$ST" 0 "" >/dev/null 2>&1
ok "ctrl-r clears the sticky query" "" "$(sed -n 2p "$ST")"

echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
