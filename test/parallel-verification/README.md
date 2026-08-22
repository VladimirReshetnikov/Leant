# Parallel-verification real-Lean gate

`../run-parallel-verification-gate.sh` treats each fixture's `+RTS -N1`
transcript as its byte-for-byte oracle, checks the expected candidate count,
and compares every exercised multicore capability against that oracle. It also
traces backend `execve` calls:

- the history-free, two-group fixture must use one primary backend at `-N1`
  and one primary plus exactly two isolated workers at both `-N2` and `-N4`;
- the history-free, five-result fixture must use total backend counts of one,
  three, four, and five at `-N1`, `-N2`, `-N3`, and `-N4`, respectively, while
  returning the same five candidates at every capability count;
- the pristine hidden-type fixture must exercise the one-versus-three parallel
  verification route at both `-N2` and `-N4`, but return no verified candidates
  at any capability count. Its Lean-only type is intentionally visible to the
  synthesis translator but absent from the user's pristine environment, so it
  rejects a regression that initializes workers from a richer imported
  environment;
- the session-created scoped-notation fixture must return five candidates and
  use only its primary backend at `-N1`, `-N2`, and `-N4`.

On Linux, process-route tracing is required by default. Set
`LEANT_ROUTE_TRACE=skip` only when ptrace is deliberately unavailable; this
keeps the transcript/candidate assertions but prints an explicit route-evidence
skip. `LEANT_ROUTE_TRACE=require` requires `strace` on any platform.

The Linux cache discovery path is not portable, so point `LEANT_BACKEND` at the
real Lean REPL executable. `LEANT_EXE` may similarly select an already-built
Leant executable; otherwise the runner resolves the current Cabal build. The
runner never builds either executable.

```console
LEANT_BACKEND=/path/to/repl ./test/run-parallel-verification-gate.sh
```

Each command gets a private temporary directory whose path contains spaces.
The gate also gives its warm commands one private XDG cache path containing
spaces. The first history-free N1 command must publish exactly one
content-addressed serializer module. Every subsequent warm command must leave
that module's checksum unchanged. A Linux trace proves an exact one-open count
for the primary backend in every warm command; the initial cold publisher and
separate cold N2 publisher do not reopen their newly published final paths.
The same traces require the command-scoped
`leant-parallel-verification` marker to be present exactly when the route is
eligible and absent otherwise. After every command, independently of route
tracing, the filesystem check requires that no such temporary artifact remains.

A separate cold N2 run preserves the earlier gate: it uses a second private
cache, proves the same transcript and three-backend topology, publishes exactly
one compiled tooling module, exercises the verification-artifact route, and
does not reopen that newly published final path. This keeps the cache's
cold-export, warm-import, and verification-snapshot paths inside the same
real-Lean parity/topology gate rather than inferring them from timing.

Every command runs under the same deterministic outer TERM/KILL watchdog. It
defaults to 900 seconds and can be changed with
`LEANT_GATE_TIMEOUT_SECONDS`; Leant's synthesis budget defaults to 600 seconds
and can be changed with `LEANT_SYNTH_TIMEOUT`.
