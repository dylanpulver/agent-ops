# Pattern 04 — Config sync

**N config dirs, one source of truth: symlink what can't be allowed to drift, sync what
must be copied.**

## The problem

Serious parallel operation eventually means multiple Claude Code config dirs — one per
account — so sessions can run concurrently under separate auth and separate rate limits:

```
~/.claude      # canonical
~/.claude-b    # second account
~/.claude-c    # third account
```

(Launch against a given dir with `CLAUDE_CONFIG_DIR=~/.claude-b claude` — a shell alias
per account makes this one keystroke.)

Each dir carries its own `settings.json`, hooks, skills, memory, and instructions. The
moment there are two, they start drifting: a hook fixed in one dir but not the others, a
permission added here but not there. Drift is poisonous precisely because it's invisible —
every session *looks* the same until one behaves differently, and "works in this terminal
but not that one" becomes its own debugging category. **The operating rule: all config dirs
must behave identically; any drift between them is a bug, not a curiosity.**

## The mechanism

**One git-tracked source of truth** — a config repo (e.g. `~/Repos/claude-config/`) that
the canonical `~/.claude` symlinks into. Every other config dir derives from it. Two
propagation modes, chosen per file by one question: *can this file be shared literally, or
does the tool insist on a private copy?*

### Symlink what can't be allowed to drift

Files every dir can share byte-for-byte get **one real file, N symlinks**:

- `CLAUDE.md` (global instructions) — every config dir's copy is a symlink to the same
  source file. It *cannot* drift; edit it once and every session everywhere sees it.
- Skills, commands, hooks directories — same treatment.

Symlinks are the strongest sync: there is nothing to reconcile because there is only one
file. Prefer them everywhere the tool tolerates them.

### Sync-copy what must be a real file

Some files can't be symlinked everywhere — the tool rewrites them, or they mix shared keys
with per-dir state (auth, history). `settings.json` is the classic case: the canonical dir
symlinks it to the source, but the other dirs hold **real copies synced from it**. Copies
*can* drift, so they need two supports:

1. **A sync step** that reasserts the copies from source — run it after edits, wire it into
   a session-start hook, or both. Make it idempotent so running it twice is free.
2. **A social rule**: *never hand-edit a derived dir.* All changes go to the source repo
   and propagate. A hand-edit to `~/.claude-b/settings.json` is drift with a countdown
   timer — it either diverges silently or gets overwritten by the next sync. Both are bugs.

### What stays per-dir on purpose

Auth/credentials, session history, and per-account caches are the *point* of having
multiple dirs — they must not be synced. The discipline is knowing which bucket each file
belongs to: shared-by-symlink, shared-by-sync, or deliberately private.

## Adding a new config dir

Mechanical, five minutes:

1. Create the dir; log the new account in once.
2. Symlink the symlink-class files (`CLAUDE.md`, skills, hooks) to the canonical ones.
3. Seed the copy-class files (`settings.json`) from source via the sync step.
4. Add the shell alias.
5. Register it wherever your tooling enumerates dirs (sync scripts, dashboards).

Script this the second time you do it. A `link-profile` helper that does steps 2–3 in one
command removes the last excuse for hand-copying.

## Why the source of truth is a git repo

- **Drift detection for free** — `git status` in the config repo shows any local mutation
  the tool made behind your back.
- **History** — "when did this hook change and why" is answerable.
- **Recovery** — a new machine, or a trashed config dir, rebuilds from clone + sync.
- **Review** — config changes get commits, and commits get read. Keep them clean: don't
  bundle unrelated changes into config-repo commits.

## Interaction with the other patterns

This pattern is load-bearing for the rest of the repo. The board hook
([Pattern 01](01-session-board.md)) only produces one unified board because every config
dir runs the identical hook pointed at the same file. Handoff and ledger conventions only
hold across accounts because every dir shares the same instructions. Config sync is what
turns "several accounts" into "one workforce."
