# Parallel-verification real-Lean gate

`../run-parallel-verification-gate.sh` runs both fixtures with `+RTS -N1`
and `+RTS -N2`. It requires their normalized transcripts to be byte-identical
and checks their candidate counts. It also traces backend `execve` calls:

- the history-free, two-group fixture must use one primary backend at `-N1`
  and one primary plus exactly two isolated workers at `-N2`;
- the session-created scoped-notation fixture must return five candidates and
  use only its primary backend at both capability counts.

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

Each run gets a private temporary directory whose path contains spaces. The
outer watchdog defaults to 900 seconds per run and can be changed with
`LEANT_GATE_TIMEOUT_SECONDS`; Leant's synthesis budget defaults to 600 seconds
and can be changed with `LEANT_SYNTH_TIMEOUT`.
