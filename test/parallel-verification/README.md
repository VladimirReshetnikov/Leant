# Parallel-verification real-Lean gate

`../run-parallel-verification-gate.sh` runs all fixtures with `+RTS -N1`
and `+RTS -N2`. It requires their normalized transcripts to be byte-identical
and checks their candidate counts. It also traces backend `execve` calls:

- the history-free, two-group fixture must use one primary backend at `-N1`
  and one primary plus exactly two isolated workers at `-N2`;
- the pristine hidden-type fixture must exercise the one-versus-three parallel
  verification route but return no verified candidates at either capability
  count. Its Lean-only type is intentionally visible to the synthesis
  translator but absent from the user's pristine environment, so it rejects a
  regression that initializes N2 workers from a richer imported environment;
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
gate also gives the whole run a private XDG cache path containing spaces. The
first history-free N1 command must publish exactly one content-addressed
serializer module; the N2 command must leave its checksum unchanged, and a
Linux trace must prove that the warm primary backend opened that exact module
once. Warm and cold N2 traces must both exercise the command-scoped
`leant-parallel-verification` snapshot route, while the filesystem check
requires that its temporary artifact is removed before the command returns. A
separate cold N2 run uses a second private cache, proves the same transcript and
three-backend topology, publishes exactly one compiled tooling module, and does
not reopen that newly published final path. This keeps the cache's cold-export,
warm-import, and verification-snapshot paths inside the same real-Lean
parity/topology gate rather than inferring them from timing.

The outer watchdog defaults to 900 seconds per run and can be changed with
`LEANT_GATE_TIMEOUT_SECONDS`; Leant's synthesis budget defaults to 600 seconds
and can be changed with `LEANT_SYNTH_TIMEOUT`.
