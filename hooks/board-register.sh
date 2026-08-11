#!/bin/bash
# board-register.sh — live session board for parallel Claude Code sessions.
#
# One file that every session (across ALL config dirs/accounts) registers into:
#   ~/.claude-sessions/board.jsonl — one JSON line per live session:
#   {"sid":"...","cwd":"...","cfg":"...","seen":"YYYY-MM-DD HH:MM","doing":"..."}
#
# Wire the same script to three hook events (see settings.snippet.json):
#   SessionStart     -> registers the session
#   UserPromptSubmit -> heartbeat: refreshes last-seen + current intent
#   SessionEnd       -> deregisters
#
# Design notes:
#   - Advisory, not a lock. Races between parallel writers can drop a row; it
#     self-heals on that session's next prompt. Stale rows (>24h) are pruned on
#     every write, so crashed sessions age off without an administrator.
#   - Must NEVER break a session: every failure path exits 0.
set -uo pipefail

command -v jq >/dev/null || exit 0

# Hook stdin is a JSON object; the fields we need:
#   .session_id       — unique per session (our dedupe key)
#   .hook_event_name  — SessionStart | UserPromptSubmit | SessionEnd
#   .cwd              — the session's working directory
#   .prompt           — the just-submitted user prompt (UserPromptSubmit only)
IN=$(cat)
SID=$(jq -r '.session_id // empty' <<<"$IN"); [ -n "$SID" ] || exit 0
EVENT=$(jq -r '.hook_event_name // empty' <<<"$IN")
CWD=$(jq -r '.cwd // empty' <<<"$IN")
PROMPT=$(jq -r '.prompt // empty' <<<"$IN" | tr -d '\n' | cut -c1-80)

# Machine-generated prompts must not overwrite a session's real intent.
# Extend this list with your own automation's prompt prefixes (scheduled runs,
# review triggers, task notifications, bare "#" memory-adds, ...).
case "$PROMPT" in
  "[scheduled "*|"<task-notification>"*|"Review this change for security"*|"#") exit 0;;
esac

DIR="$HOME/.claude-sessions"; BOARD="$DIR/board.jsonl"
mkdir -p "$DIR"; touch "$BOARD"

NOW=$(date '+%Y-%m-%d %H:%M')
# 24h-ago cutoff, BSD (macOS) or GNU date:
CUTOFF=$(date -v-24H '+%Y-%m-%d %H:%M' 2>/dev/null || date -d '24 hours ago' '+%Y-%m-%d %H:%M')

# Which config dir (account) this session runs under — how a multi-account
# setup tells its sessions apart on one shared board.
CFG=$(basename "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")

TMP="$BOARD.tmp.$$"
{
  # Keep every row except this session's old one...
  grep -v "\"sid\":\"$SID\"" "$BOARD" 2>/dev/null || true
  # ...and append the fresh row (unless the session is ending).
  if [ "$EVENT" != "SessionEnd" ]; then
    jq -cn --arg sid "$SID" --arg cwd "$CWD" --arg cfg "$CFG" --arg seen "$NOW" --arg doing "$PROMPT" \
      '{sid:$sid, cwd:$cwd, cfg:$cfg, seen:$seen, doing:$doing}'
  fi
} | jq -c --arg cutoff "$CUTOFF" 'select(.seen >= $cutoff)' > "$TMP" 2>/dev/null && mv "$TMP" "$BOARD"
rm -f "$TMP" 2>/dev/null

exit 0
