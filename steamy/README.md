# steamy fork of ralph-orchestrator

This fork carries a minimal patch set on top of each upstream release tag,
built and installed into the sandbox's npm-managed `ralph` binary. Owned and
maintained by the steamy build loop's operator setup.

## The patches (one commit each, no other changes)

1. **`fix(cli-executor)` — spawn headless sessions in the configured workspace root.**
   The no-TUI executor (`CliExecutor`, used by every `ralph run -a`) spawned
   backend sessions with `cwd = current_dir()` of the driver process and injected
   `RALPH_WORKSPACE_ROOT`/`RALPH_EVENTS_FILE` from it. Worktree-loop drivers keep
   `cwd` at the primary checkout, so their sessions: (a) ran and edited in the
   primary tree, (b) emitted `build.done` into the primary's events file where the
   worktree driver never sees it (the builder→reviewer handoff silently fails and
   the loop dies with `consecutive_failures`), and (c) resolved `ralph tools` CLIs
   against the primary store. Fix: `CliExecutor::with_workspace_root(...)` —
   `loop_runner.rs` now passes `config.core.workspace_root` (already set to the
   worktree by the worktree run path). The PTY path already did this correctly.

2. **`fix(loop-lock)` — tolerate the empty create-to-write window.**
   `try_acquire` re-reads the holder's metadata after `flock(EWOULDBLOCK)`. A
   concurrent opener could observe the file in the instant between the winner's
   create and its metadata write and abort with `Failed to parse lock metadata:
   Empty lock file`. Fix: retry the read briefly; if still empty, report an
   unknown holder instead of failing the launch.

## Build and install

```bash
cd /home/agent/forks/ralph-orchestrator
source ~/.cargo/env
cargo build --release -p ralph-cli          # ~45 s incremental, ~5 min cold
target/release/ralph --version              # smoke

# install: sandbox `ralph` is pnpm-managed; swap the binary in place
BIN=$(readlink -f "$(which ralph)")
cp "$BIN" "$BIN.stock-2.12.0"               # keep the stock binary next to it
cp target/release/ralph "$BIN"
```

The swap survives until `pnpm update -g @ralph-orchestrator/ralph-cli` — which
restores the stock binary and must be followed by re-running the two `cp` lines.
The running loops are unaffected by a swap (already-loaded code); only new
`ralph` invocations pick it up.

## Updating to a new upstream release

```bash
cd /home/agent/forks/ralph-orchestrator
git fetch upstream
./steamy/rebase-onto-tag.sh v2.12.1         # or whatever the new tag is
cargo build --release -p ralph-cli && target/release/ralph --version
# then swap the binary per the install section
```

If a patch commit no longer applies cleanly, resolve the conflict by re-reading
the upstream change — the two fixes above touch `cli_executor.rs`,
`loop_runner.rs` (one line) and `loop_lock.rs`. Re-check the PTY path
(`pty_executor.rs`) still threads `workspace_root` so both executors stay in
agreement.
