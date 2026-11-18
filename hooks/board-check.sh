#!/bin/bash
# board-check.sh: list the other live sessions working in the same repo.
#
# Run it before grabbing batch work (a migration, a backlog sweep, anything two
# sessions could both take). It reads ~/.claude-sessions/board.jsonl, written by
# board-register.sh, and prints every session whose cwd is inside this repo.
#
#   board-check.sh            # the repo containing the current directory
#   board-check.sh ~/code/api # a specific repo
#   board-check.sh --sid ID   # leave out your own session
#
# Exit 0 when nobody else is there, 1 when someone is, so a script can gate on it.
set -uo pipefail

command -v jq >/dev/null || { echo "board-check: needs jq" >&2; exit 0; }

SID=""; DIR="."
while [ $# -gt 0 ]; do
  case "$1" in
    --sid) SID="${2:-}"; shift 2;;
    *) DIR="$1"; shift;;
  esac
done

BOARD="$HOME/.claude-sessions/board.jsonl"
[ -s "$BOARD" ] || { echo "board is empty"; exit 0; }

ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$DIR" && pwd -P))
# macOS reports some paths with and some without /private (/var, /tmp), so match both.
ALT="${ROOT#/private}"

ROWS=$(jq -r --arg root "$ROOT" --arg alt "$ALT" --arg sid "$SID" '
  select(.sid != $sid)
  | .cwd as $c
  | select([$root, $alt] | any(. as $r | $c == $r or ($c | startswith($r + "/"))))
  | "\(.sid)  \(.cfg)  \(.seen)  \(.doing)"' "$BOARD" 2>/dev/null)

if [ -z "$ROWS" ]; then
  echo "no other sessions in $ROOT"
  exit 0
fi
echo "other sessions in $ROOT:"
echo "$ROWS"
exit 1
