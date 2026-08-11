# Pattern 01 — The session board

**An advisory presence board every live session self-registers to, so no two sessions grab
the same work.**

## The problem

Run three Claude Code sessions at once and sooner or later two of them will independently
decide the same batch is theirs: the same migration, the same bulk refactor, the same queue
of items to process. Neither session can see the other. Each one is locally correct and
globally wrong. You discover the collision at merge time, or worse, after a shared resource
has been processed twice.

Sessions are blind to each other by design — separate processes, separate contexts,
possibly separate accounts. What's missing is the thing every human team has for free:
peripheral vision. You can see your coworker is at the whiteboard. A session can't.

## The mechanism

One shared file: `~/.claude-sessions/board.jsonl`. One row per live session:

```json
{"sid":"<session-uuid>","cwd":"/path/to/repo","cfg":".claude-b","seen":"2026-08-11 14:02","doing":"migrate the events table to the new schema"}
```

- **sid** — the session ID, from the hook's stdin JSON. The dedupe key.
- **cwd** — which repo/directory the session is working in.
- **cfg** — which config dir (account) it runs under, from `$CLAUDE_CONFIG_DIR`.
- **seen** — last activity timestamp.
- **doing** — the first ~80 chars of the latest user prompt: a good-enough proxy for intent.

A single hook script ([`hooks/board-register.sh`](../hooks/board-register.sh)) is wired to
three hook events in `settings.json`:

- **SessionStart** — registers the session (row appears).
- **UserPromptSubmit** — refreshes the row: updates `seen` and `doing` on every prompt.
  This is the heartbeat, and it's what keeps `doing` current as the session's work shifts.
- **SessionEnd** — deregisters (row removed).

Every write also prunes rows not seen in 24h, so crashed or killed sessions age off the
board on their own. Nobody administers this file; it maintains itself.

## The protocol

The hook is half the pattern. The other half is one standing rule in your global CLAUDE.md:

> Before starting work on a **shared resource** — a batch job, a bulk sweep, a migration,
> anything two chats could both grab — read `~/.claude-sessions/board.jsonl` and check for
> another session in the same repo with overlapping intent. If one exists: pick
> non-overlapping work, or say so and let the human arbitrate.

Note the scope: *batch-type work on shared resources*. Ordinary work — editing different
files, answering questions, working different repos — doesn't need a board check. The check
is mandatory only where collisions are expensive.

## Advisory, not a lock — on purpose

The obvious "improvement" is to make the board a real lock: acquire before working, block
if held. Don't. In practice, advisory wins:

- **Locks need an administrator.** A crashed session holding a lock blocks everything until
  a human notices. A crashed session on an advisory board is just a stale row that ages off
  in 24h.
- **The failure mode is asymmetric.** A missed advisory check costs you one duplicated
  batch — annoying, recoverable. A wedged lock costs you a blocked workforce and a
  debugging session.
- **Intent isn't machine-comparable.** "Overlapping intent" is a judgment call over two
  free-text `doing` fields. An LLM session is genuinely good at that comparison; a lock
  manager isn't. Lean into what the reader is good at.
- **Races self-heal.** Two sessions writing the board simultaneously can clobber each
  other's row — and the row reappears on the loser's next prompt. Eventual consistency is
  plenty for peripheral vision.

The board is a **presence** system, not a **mutex**. It makes collisions rare and visible,
not impossible. That's the right trade for this workload.

## Failure modes seen in practice

- **Machine-generated prompts pollute `doing`.** Scheduled runs, security-review triggers,
  task notifications, and bare `#` memory-add prompts all fire UserPromptSubmit and will
  overwrite a session's real intent with noise. The hook filters these out — extend the
  filter list as your own automation grows.
- **jq missing.** The hook exits 0 silently rather than breaking sessions. Board hooks must
  never be able to take a session down; the board is worth nothing if it costs reliability.
- **Concurrent writes.** Mitigated with write-to-temp-then-rename (atomic on POSIX). Losses
  still possible, self-healing as above.

## Install

1. `cp hooks/board-register.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/board-register.sh`
2. Merge [`hooks/settings.snippet.json`](../hooks/settings.snippet.json) into your `settings.json`.
3. Add the check-before-batch-work rule to your global CLAUDE.md.
4. If you run multiple config dirs (see [Pattern 04](04-config-sync.md)), install in the
   *source* config and let sync propagate — the whole point is that every account's
   sessions land on the same board.
