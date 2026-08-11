# Pattern 03 — The state ledger

**A per-repo "where are we" file that outlives every session — and is verified against git
reality before it's trusted.**

## The problem

"Where are we at?" is the most-asked question in a multi-session setup — asked dozens of
times a month, in practice — and the natural place to answer it from is chat memory. Chat
memory is exactly the wrong place. It dies with the session, degrades with every
compaction, and no session can see what its siblings did. The result is re-orientation tax:
every fresh session spends its first ten minutes reconstructing state that some other
session already knew, and every long session drifts toward confidently wrong answers about
what's done.

## The mechanism

One file per repo:

```
<repo>/.claude/state.md
```

Fixed sections (template: [`templates/state-ledger-template.md`](../templates/state-ledger-template.md)):

```markdown
# State — <repo>
Updated: YYYY-MM-DD (session gist)

## In flight
- <workstream>: <one-line status> — next: <action> (blocked on: <who/what>, since <date>)

## Done recently
- YYYY-MM-DD <thing shipped/merged/decided>

## Sent
- YYYY-MM-DD <recipient/channel>: <one-line gist>

## Waiting on
- <who> owes <what> since <date>

## Parked / open questions
- <item>
```

The sections are chosen for the questions that actually get asked: what's moving, what
landed, what's blocked on whom, what's deliberately shelved. "Sent" earns its place the
first time you almost send the same message twice.

## The read protocol: reality wins

The ledger is a cache, and caches lie. The read protocol is non-negotiable:

1. Read `.claude/state.md`. If missing, offer to bootstrap it from `git log`, open PRs,
   and the current session.
2. **Verify against reality before answering**: `git log --oneline -15`, `gh pr list`,
   uncommitted changes. If the ledger and reality disagree, *reality wins — and fix the
   ledger in the same breath*.
3. Answer as a short re-orientation brief: what shipped, what's in flight, what's blocked
   on whom, the single next action. Not a report.

Step 2 is what separates this from "notes that drift." A ledger that's merely read
accumulates lies; a ledger that's reconciled on every read stays honest for months.

## The write protocol

- Update at the end of any substantial work session, and immediately when something ships.
- Convert relative dates ("yesterday", "last week") to absolute ones — relative dates are
  meaningless to the session reading them next month.
- **Keep it under ~60 lines.** It's a dashboard, not a journal. Prune "Done recently" past
  two weeks. The moment the ledger takes longer to read than to reconstruct, it's dead.

## Why this also fixes parallel-session collisions

The board ([Pattern 01](01-session-board.md)) covers *live* siblings; the ledger covers
*everything else*. Two chats working the same repo read and write the same ledger, so
"heads up, that batch is already underway" no longer needs hand-pasting between chats.
The discipline that makes it work: **when starting a batch, write it under "In flight"
immediately** — before doing the work, not after. A sibling session (or tomorrow's session,
or tonight's overnight run) reads that line and routes around you.

## Ledger vs. handoff vs. board

Three artifacts, three time horizons — they look similar and must not be merged:

| Artifact | Horizon | Written | Read |
|---|---|---|---|
| Board (01) | Right now | Automatically, by hooks | Before batch work |
| Ledger (03) | This repo's ongoing life | By sessions, at ship/start points | At session start, on "where are we" |
| Handoff (02) | One planned piece of work | Once, at plan time | Once, at execution start |

The classic mistake is letting one absorb another — a handoff that becomes a status file,
or a ledger that swells into a project journal. Keep the boundaries and each stays cheap.
