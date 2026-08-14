# Length certificate-carrier handoff

Date: 2026-08-13

## Outcome

Leant now pins Djex commit `3a60c1af`, which includes the Length consumer at
`3d428bbd`, the exact-assignment association-priority fix at `c09ddac3`, and its
fallback-order regression pin. Length privately consumes the opaque certificate
association retained inside an Exference typed candidate, while productive
exact assignments reach that associated candidate before the legacy plain
fallback. No Leant production adapter changed. The existing semantic sidecar
already stores the whole candidate, and `Leant.Synth.Length.Handoff` already
passes that candidate unchanged to the session-owned Djex problem sealer.

This is deliberately different from projecting `typedCandidateTermGraph`.
Rendering may use that public bare graph as an observation, but a stamped
projection has lost its certificate-association authority and
`fingerprintSharedTermGraph` rejects it. The whole candidate lets Djex freshly
reseal the graph with the exact Length session schema, authorize every rooted
association row, and then interpret the graph.

## Admitted authority

The first Djex consumer admits only a narrow provider case. Every associated
row must name the exact source-inventory owner, retain an alpha-exact complete
source scheme, have a checked Length provider summary, and contain no activated
obligations. Modeled zero/step constructors remain unsupported as certificate
owners. A detached stamped graph cannot recover this authority.

Empty activated obligations are a structural policy condition, not evidence
that a Haskell dictionary or class instance was discharged. Leant supplies no
query-given or typeclass-resolution receipt, and Z3 runs only after the checked
Length problem exists; it cannot establish source-language class evidence.
Contextual associated candidates therefore continue to fail closed. Solver
status remains heuristic until exact problem-bound counterexample replay
succeeds, just as before this checkpoint.

## Identity migration

Plain graphs and empty carriers retain their existing graph and candidate v1
identities. A nonempty authorized carrier uses Djex's semantic graph v2 and
candidate v2. Djex also advances the common Length session-policy versions from
2/3/4 to 5/6/7 because the admitted candidate language changed. Consequently
old containing session, concrete, problem, query, and protocol cache keys are
invalid. Contract grammar and public Leant handoff signatures do not change,
and explicit-all-observed policy remains equivalent to the current legacy
policy.

The initial carrier pin advanced directly from `aa73fbb` to the post-consumer
commit `3d428bbd`; this follow-up advances it to `3a60c1af`. Intermediate Djex
certificate commits were intentionally not pinned as green Leant states:
before the Length consumer landed, Exference could project a stamped graph
which the legacy Length fingerprint correctly rejected.

## Regression and compatibility

The existing polymorphic provider regression now proves both sides of the
boundary. `Demo.emptyPolyList :: forall a. List a` produces one slot-zero
certificate handle. Its projected bare graph receives the exact public
`TermGraphFingerprintUnsupportedCertificate` refusal, while the original whole
candidate passes through callback verification and the production Length
handoff, yielding result length zero and the exact checked provider law.

No Leant schema, wire format, ranking rule, rendered Lean term, SMT-LIB
lowering, or public API changed. One pre-existing test helper was made exhaustive
over all `ProviderFrag` constructors so the strict build remains clean under
`-Wincomplete-record-selectors`.

The Lean-backed transcript pass uses the matching upstream Lean 4.31 REPL. All
synthesis transcripts pass after recording the intentional exact-assignment
ordering and bounded-search telemetry changes from `c09ddac3`. The independent
`prove-suggest` transcript remains environment-limited here: automatic tactic
suggestion exceeds Leant's existing 300-second backend-request timeout and the
backend is deliberately discarded. Its input and golden are unchanged, and it
does not exercise the Djex synthesis path.
