# agent-ops

[![CI](https://github.com/dylanpulver/agent-ops/actions/workflows/ci.yml/badge.svg)](https://github.com/dylanpulver/agent-ops/actions/workflows/ci.yml)

**How to run Claude Code as a team of agents.**

Operational patterns for running many Claude Code sessions in parallel — across terminals,
accounts, and config dirs — as one coordinated workforce instead of a pile of amnesiac chats.

These are not thought experiments. Every pattern here has been run daily for months across
3+ parallel accounts. This repo is the distilled mechanics: what breaks when you scale from
one session to many, and the small, boring pieces of infrastructure that fix it.

## Why parallel sessions at all

One Claude Code session is an assistant. Five concurrent sessions — one planning, one
executing a refactor, one sweeping a backlog, one on a different repo, one queued for
tonight — are a workforce. Rate limits, context windows, and human attention all parallelize
better than they serialize. The ceiling on output stops being "how fast can one chat go" and
becomes "how well do the chats coordinate."

That coordination does not happen by itself. Scale past two sessions and three failure modes
show up almost immediately:

1. **Duplicate work.** Two sessions grab the same batch, the same migration, the same sweep —
   and you find out when the second one hits a merge conflict or double-processes half the
   queue.
2. **Lost context.** The plan lived in chat A; execution starts in chat B with none of it.
   Decisions get re-litigated, gotchas get re-discovered, and "where were we?" gets answered
   from memory — wrongly.
3. **Idle hours.** The work that needed no human — bulk transforms, report generation,
   sweep-and-fix passes — sat in a queue of one (your head) while every session slept.

A fourth, quieter one arrives when you run multiple config dirs for multiple accounts:
**configuration drift** — three environments that were supposed to be identical, slowly
diverging until "works in this terminal, not that one" becomes a debugging category.

## The five patterns

| # | Pattern | Fixes |
|---|---------|-------|
| [01](patterns/01-session-board.md) | **Session board** — every live session self-registers to a shared JSONL presence board via hooks; sessions check it before grabbing batch work | Duplicate work |
| [02](patterns/02-handoff.md) | **Handoff docs** — plan in one chat, write a standardized handoff file, execute in a fresh chat with full context | Lost context (between chats) |
| [03](patterns/03-state-ledger.md) | **State ledger** — a per-repo "where are we" file that outlives every session and is verified against git reality | Lost context (over time) |
| [04](patterns/04-config-sync.md) | **Config sync** — N config dirs, one git-tracked source of truth: symlink what can't drift, sync what must be copied | Configuration drift |
| [05](patterns/05-overnight-queue.md) | **Overnight queue** — bank autonomous-shaped work into a queue; a scheduler runs it headless while you sleep | Idle hours |

The patterns compose. The board tells a session what its siblings are doing *right now*;
the ledger tells it what happened *before it existed*; the handoff tells it what it was
*born to do*; the overnight queue extends all of that into hours when no human is watching;
and config sync guarantees every one of those sessions behaves identically no matter which
account it runs under.

## Working artifacts

Doctrine is in `patterns/`. The pieces you actually install are:

- [`hooks/board-register.sh`](hooks/board-register.sh) — a working session-board hook
  (registers, refreshes, deregisters, prunes stale rows)
- [`hooks/settings.snippet.json`](hooks/settings.snippet.json) — the hooks config fragment
  to merge into your `settings.json`
- [`templates/handoff-template.md`](templates/handoff-template.md) — the handoff document skeleton
- [`templates/state-ledger-template.md`](templates/state-ledger-template.md) — the per-repo ledger skeleton

## Quick start

```bash
# 1. Install the board hook
mkdir -p ~/.claude/hooks
cp hooks/board-register.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/board-register.sh

# 2. Merge hooks/settings.snippet.json into ~/.claude/settings.json

# 3. Teach your sessions the protocol (global CLAUDE.md):
#    "Before starting batch-type work on a shared resource, read
#     ~/.claude-sessions/board.jsonl and check for a sibling session
#     in the same repo with overlapping intent."
```

Then read the patterns in order. Each one stands alone, but 01–03 are the core loop.

## License

MIT — see [LICENSE](LICENSE).
