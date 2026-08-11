# Pattern 02 — The handoff doc

**Plan in one chat, execute in a fresh one — with a standardized document as the interface.**

## The problem

Planning and execution want different sessions. Planning fills a context window with
exploration, dead ends, and debate; by the time the plan is solid, the session is heavy,
slow, and one compaction away from forgetting its own conclusions. Execution wants the
opposite: a cold, light session with exactly the distilled plan and nothing else.

The naive handoff is "summarize this chat so I can paste it into a new one." Done ad hoc,
it fails the same ways every time: the summary skips the *reasons* behind decisions (so the
executor re-litigates them), skips the gotchas (so the executor re-discovers them the hard
way), and lives in a paste buffer instead of a file (so it's gone by tomorrow). Before
standardizing, the same handoff-request boilerplate got retyped session after session, and
orphaned `HANDOFF-*.md` files accumulated in repo roots.

## The mechanism

A handoff is a **file with a fixed shape in a fixed place**:

```
<repo>/.claude/handoffs/<topic>-YYYY-MM-DD.md
```

plus one index line in `.claude/handoffs/INDEX.md` (date, topic, path, status). Never the
repo root — root-level handoff files rot into permanent clutter.

The fixed sections, in order (template: [`templates/handoff-template.md`](../templates/handoff-template.md)):

| Section | Why it exists |
|---|---|
| **Goal** | One paragraph. The executor's north star. |
| **Architecture / how it works** | Only what the executor must know, with real file paths. Not a tour. |
| **Decisions made (and why)** | The "why" is the load-bearing part — it's what stops re-litigation. |
| **Current status** | Done / in-flight / not started. |
| **Exact next steps** | Numbered, concrete, in order. The executor starts at step 1. |
| **Open questions** | Decisions the executor should *surface, not make*. The autonomy boundary. |
| **Artifacts** | Files, PRs, URLs, commands that matter. |
| **Gotchas** | Anything that already bit once. The most valuable section per word. |

The test for a good handoff: **a cold session needs nothing else.** If the executor would
have to ask "why did we choose X?" or "where is Y?", the handoff is incomplete.

## The two modes

**Write mode** (end of a planning session): produce the file, index it, and hand the human
a one-liner to start the next chat with:

```
read .claude/handoffs/<file> and continue
```

**Consume mode** (start of an execution session): read the handoff fully, confirm
understanding in three lines (goal, next step, first action), mark it consumed in
INDEX.md — then start executing.

## The rule that keeps it working: handoffs are launch documents

A handoff is written once and consumed once. **Do not maintain it during execution.** The
moment a handoff doubles as a status file, you have two competing sources of truth and both
go stale. Ongoing state belongs in the per-repo state ledger
([Pattern 03](03-state-ledger.md)); the handoff is the rocket, the ledger is mission
control. This division took real friction to learn — the instinct to "update the handoff"
mid-execution is strong and wrong.

## Why a file and not a summary paste

- **Durable** — survives the paste buffer, the terminal, and the day. Execution can start
  tomorrow, or on another machine, or in a session run by a different account.
- **Reviewable** — the human can read and correct the plan before any execution happens.
  This is the cheapest possible checkpoint between "agent decided" and "agent did."
- **Repeatable** — if execution goes sideways, kill the session and consume the same
  handoff again in a fresh one. The plan wasn't in the dead chat.
- **Composable** — an overnight job ([Pattern 05](05-overnight-queue.md)) can point at a
  handoff as its briefing. Plan at 6pm, execute unattended at 2am.

## Hygiene

If stale `HANDOFF-*.md` files litter a repo root, move them into `.claude/handoffs/` and
index them. Offer once, don't nag.
