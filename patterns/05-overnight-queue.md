# Pattern 05 — The overnight queue

**Bank autonomous-shaped work into a queue during the day; a scheduler runs it headless
while you sleep.**

## The problem

An agent workforce that only works when a human is watching wastes a third of the clock.
By late evening there's usually a pile of work that needs no judgment mid-flight — bulk
transforms, corpus/batch processing, sweep-and-fix passes, report generation — and it sits
untouched until morning because every session ended when the human did. Meanwhile,
subscription rate limits that constrain a busy afternoon are wide open at 3am.

## The mechanism

Three pieces:

### 1. The queue — one JSONL file

```
~/.claude-queue/overnight.jsonl
```

One job per line:

```json
{"queued":"<ISO timestamp>","cwd":"<absolute repo path>","prompt":"<self-contained task>","note":"<one-line label for the morning report>"}
```

Example:

```json
{"queued":"2026-08-11T00:45:00-04:00","cwd":"/home/me/repos/docs-site","prompt":"Read .claude/state.md first. Convert the remaining 14 pages under content/legacy/ to the new frontmatter format, rebuild with npm run build, and commit to a new branch legacy-migration-3. Done = build passes and no page under content/legacy/ still uses the old format.","note":"legacy migration batch 3"}
```

Queueing is cheap enough to do conversationally: any session, told "queue this for
tonight," appends a line. The natural moment is session wrap-up — when remaining work is
autonomous-shaped, bank it instead of dropping it.

### 2. The runner — a scheduled headless executor

A scheduled job (launchd on macOS, systemd timer or cron elsewhere) fires at a fixed
off-peak time — say 02:23 — and for each queued line runs Claude Code headless in the
job's `cwd` with the job's prompt. It:

- runs jobs **sequentially**, not in parallel — the night is long, and serial execution
  keeps rate limits and the board sane;
- logs each run to `~/.claude-queue/logs/`;
- appends an outcome row (done/failed + log path) to `~/.claude-queue/done.jsonl`.

### 3. The morning report

Whatever your morning-brief mechanism is, it reads `done.jsonl` and opens with the
overnight delta: what ran, what landed, what failed and where the log is. Unattended work
you never hear about might as well not have run — the report closes the loop.

## The prompt contract: it runs cold

The queued prompt is a handoff to a session with zero chat context, no human, and no
second chance to ask. Rules, learned the hard way:

- **Self-contained.** Name the files, branches, targets, and acceptance criteria
  explicitly. "Done = X" belongs in the prompt.
- **Point at durable state.** Open with "Read `.claude/state.md` first" or a handoff path
  ([Patterns 02](02-handoff.md)/[03](03-state-ledger.md)) — the ledger and handoff are how
  a cold session inherits context.
- **Autonomous-shaped only.** Batch transforms, sweeps, generation, analysis — yes.
  Anything needing human judgment mid-flight — no. If you can't write the acceptance
  criteria, it isn't autonomous-shaped yet; that's the test.
- **If details are unclear at queue time, ask then** — not at 2am, when nobody answers.

## Guardrails: the runner enforces, the queue respects

Unattended agents get a hard ceiling, enforced by the runner (via permissions and a
gatekeeping hook), not by hoping prompts behave:

- **No merging.** Results land on branches; a human merges in the morning.
- **No sending.** No messages, emails, posts, or anything that leaves the machine.
- **No data deletion.**

Corollary for queue authors: don't queue work that fights the guardrails. A job whose
success requires merging or sending will fail by design — reshape it so results land on a
branch or in a file.

## Interaction with the board

Overnight sessions are sessions: they register on the board
([Pattern 01](01-session-board.md)) like any other, and anything that queues work
automatically should check the board first — never queue a job overlapping a live
session's repo and intent. The 24h prune means last night's rows are gone before tonight's
runs begin.

## Why this compounds

The overnight queue is where the other four patterns pay off at once: config sync
guarantees the headless session behaves like every other; the ledger and handoffs give it
context; the board keeps it from colliding; and guardrails keep it shippable. In practice
this turns the queue's off-hours into the day's cheapest labor — the morning starts with
branches to review instead of work to begin.
