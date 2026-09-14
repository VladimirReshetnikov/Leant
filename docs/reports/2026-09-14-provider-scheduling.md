# Cooperative provider scheduling and deadline admission

Leant's named behavioral queries now give provider search an opportunity after the first checked structural candidate group, then resume the original structural cursor. This fixes the demonstrated admission starvation without restarting that search or refunding its allowance. The separate [namespace identity repair](2026-09-14-session-provider-identity.md) supplies the fully qualified provider names.

**The focused scheduling gate passes; original integer indexing remains open.** The final implementation passes 15 public scheduling cells across Djinn, Exference and Both, plus three existing Exference dictionary-selection cells. Together these contain 11 independently checked full-signature Lean replays with empty axiom inventories and seven actual-False controls.

## Implementation and limits

An opaque continuation retains each lane's exact lazy candidate cursor and absolute checked-group count. With a named behavioral query and provider discovery enabled, a lane yields after one checked group. Newly started provider worlds receive the accumulated checked frontier; suspended worlds resume their own existing searches. Empty provider discovery still resumes the original structural search. Constructor enrichment remains after the corresponding original pass, and constructive provider search remains before classical fallback.

The slice is a scheduling boundary, not a new user limit. Existing candidate/verification allowances, provider cap, engine settings and shared command deadline remain in force. Ordinary commands and provider-disabled commands keep their existing unsliced policy. This is cooperative scheduling: computing a single next candidate can still consume the remaining deadline.

Behavioral callbacks require a whole second of remaining allowance. The cursor now checks that same admission rule before demanding another group and again before verification. It reports already accepted results or an already reached lane cap first. This avoids enumerating candidates during a final subsecond interval in which no callback can run; it does not extend the deadline or raise per-check timeouts.

## Validation

| Check | Result |
| --- | --- |
| Final strict executable build | Passed: `cabal build leant:exe:leant --ghc-options=-Werror -j1`. |
| Public scheduling suite, final v3 | 15/15 passed across Djinn, Exference and Both: nine exact Lean replays and six actual-False controls. |
| Existing dictionary selection, Exference | 3/3 passed: ordinary and named-`where` exact replay, plus actual-False rejection; independent oracle passed. |
| Final original native Exference integer `at` | Failed to synthesize: zero passed, 23 falsified, zero inconclusive observations. Exactly the approved `BehaviorPartialNumeric.intCase` provider admitted. |
| Integer query False control and independent controls | Passed: False control has 299 falsified observations; primitive and witness preflights pass. |
| Full native unit suite | Not rerun for this increment. The preceding identity release's 768 passing tests are historical evidence for that captured revision. |

The scheduling fixtures require a namespace-qualified numeric provider, both selections of a rank-N argument, actual-False rejection with and without providers, resumed search after empty discovery, and exhaustion of the original per-lane verification allowance. No small fixture loses a behavioral request. Final source and executable integrity checks pass. The dictionary regression checks the original forced polymorphic result after dictionary application; it is not a fresh rerun of the historical 69-cell release.

The draft v1 positive scheduling fixture failed at verification allowance 3; its matching Djinn provider candidate was at ordinal 4. The positive fixture subsequently used the existing normal allowance 12 (24 for Both), while rejection/continuation fixtures retained 3 (6 for Both). These small fixture settings are independent of the original indexing limits. Intermediate v2 passed before the whole-second admission repair; v3 is the final gate. All attempts are retained.

The original indexing query keeps source `Int`, supplied default, original binder order and all 168 observations. Its settings remain window 65,536, verification 65,536, steps 100,000, budget 500,000, timeout 90 seconds and provider cap 1, with library/classical search off. Only Exference was rerun after scheduling; acceptance still requires both Haskell engines and all three native modes.

Before the deadline-admission follow-up, this query recorded 271 request failures: one actual timeout and 270 attempts with no whole second remaining. The final run records three actual timeouts and zero no-time attempts. This closes the bookkeeping defect, not the construction miss. The final query still has no matching candidate.

Two further diagnostics constrain the next triage. A small signed-integer case query succeeds by reconstructing structural cases; its candidate does not use the supplied primitive, so it does not establish provider use or Church indexing. A repeated-predicate experiment checks the inline form but fails to synthesize `Decidable` for the shared definition, leaving `sorryAx` in its rejection theorems. Its shorter runtime is invalid as speedup evidence. No production cache is introduced.

## Reproduction and archive

From the Leant root, resolve the built executable and provide the installed backend, Lake and exact Lean kernel paths:

```powershell
cabal build leant:exe:leant --ghc-options=-Werror -j1
$leantExe = (cabal list-bin leant:exe:leant).Trim()
python -X utf8 -B test-behavioral/run_provider_scheduling.py --leant $leantExe --backend $backendExe --lake $lakeExe --lean $leanExe --output dist-newstyle/provider-scheduling-recheck
python -X utf8 -B test-context/run_dictionary_selection.py --leant $leantExe --backend $backendExe --engine exference --case forced_polymorphic_result_after_dictionary --output dist-newstyle/provider-scheduling-dictionary-recheck
```

The mirrored [receipt index](../../test-church/receipts/provider-scheduling-2026-09-14.json) and [portable archive](../../test-church/receipts/provider-scheduling-2026-09-14.zip) retain exact commands, transcripts, source snapshots, controllers, build logs, kernel replays, unsuccessful attempts and interpretation notes. All 905 archive members were reopened and byte-verified. Runtime binaries are identified by hashes, not bundled. The archive is 4,967,802 bytes with SHA-256:

```text
a43e64a6b62553bd201f2439dcedcd65283e02f5bd1de6eda2500f49c8fa7fdf
```

Leant's Djex pin remains `9a2d59d958a60ff3b6899697a60b6985a5cf73a3`. No new Church behavior acceptance is claimed. The [current priorities](2026-09-14-synthesis-next-priorities.md) separate kind integration, indexing construction, the original simultaneous universe query and further ideas.
