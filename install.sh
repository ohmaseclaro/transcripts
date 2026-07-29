#!/usr/bin/env sh
# transcripts installer.
#
#   curl -fsSL https://raw.githubusercontent.com/ohmaseclaro/transcripts/main/install.sh | sh
#
# Installs the `transcripts` CLI into ~/.local/bin, and — if Claude Code or Cursor is present —
# the find-and-read-transcripts agent skill, so your agent can search your own past sessions.
#
# Knobs (env):
#   TRANSCRIPTS_BIN=~/bin        where to put the CLI          (default ~/.local/bin)
#   TRANSCRIPTS_REF=v1.9.0       branch/tag to install         (default main)
#   TRANSCRIPTS_REPO=you/fork    source repo                   (default ohmaseclaro/transcripts)
#   TRANSCRIPTS_NO_SKILL=1       CLI only, skip the agent skill
set -eu

REPO="${TRANSCRIPTS_REPO:-ohmaseclaro/transcripts}"
REF="${TRANSCRIPTS_REF:-main}"
BASE="https://raw.githubusercontent.com/$REPO/$REF"
BIN="${TRANSCRIPTS_BIN:-$HOME/.local/bin}"
SKILL="find-and-read-transcripts"

say()  { printf '%s\n' "$*"; }
warn() { printf '!  %s\n' "$*" >&2; }
die()  { printf 'installer: %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 is required (macOS: xcode-select --install)"
command -v curl    >/dev/null 2>&1 || die "curl is required"

fetch() { # fetch REMOTE_PATH LOCAL_PATH — atomic: download to a temp file, then move
  tmp="$2.part.$$"
  curl -fsSL "$BASE/$1" -o "$tmp" || { rm -f "$tmp"; die "download failed: $BASE/$1"; }
  [ -s "$tmp" ] || { rm -f "$tmp"; die "empty download: $BASE/$1"; }
  mv -f "$tmp" "$2"
}

# ---------------------------------------------------------------------------- CLI
mkdir -p "$BIN"
fetch transcripts "$BIN/transcripts"
chmod +x "$BIN/transcripts"
say "✔ installed $BIN/transcripts ($("$BIN/transcripts" --version))"

# ---------------------------------------------------------------------------- agent skill
if [ "${TRANSCRIPTS_NO_SKILL:-0}" != "1" ]; then
  installed_skill=0
  for root in "$HOME/.claude/skills" "$HOME/.cursor/skills"; do
    parent="$(dirname "$root")"
    [ -d "$parent" ] || continue          # that agent isn't installed here
    mkdir -p "$root/$SKILL"
    fetch "skill/$SKILL/SKILL.md" "$root/$SKILL/SKILL.md"
    say "✔ installed skill $root/$SKILL"
    installed_skill=1
  done
  [ "$installed_skill" = 1 ] || say "·  no ~/.claude or ~/.cursor found — skipped the agent skill"
fi

# ---------------------------------------------------------------------------- PATH
case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    warn "$BIN is not on your PATH. Add it:"
    printf '\n    echo '\''export PATH="%s:$PATH"'\'' >> ~/.zshrc && exec zsh\n\n' "$BIN"
    ;;
esac

command -v fzf >/dev/null 2>&1 || say "·  optional: 'brew install fzf' unlocks the full TUI (live filter + preview pane)"

say ""
say "Run it:  transcripts            # browse"
say "         transcripts --doctor   # check what it can see"
