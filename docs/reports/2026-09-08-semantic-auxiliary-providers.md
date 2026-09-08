# Semantic auxiliary-provider filtering and tree deadline correction

Leant now excludes Lean-generated auxiliary recursors during automatic provider
discovery, using `Lean.isAuxRecursor env n`. The shared ordinary/contextual
generator previously filtered name components but missed constructor-specific
`.elim` helpers. An ordinary user declaration named `elim` remains eligible.
This repairs provider admission; it does not add an accumulator implementation.

The [evidence receipt](../../test-context/receipts/semantic-auxiliary-providers.json) retains exact emitted programs, inventories,
public commands, runtime hashes, failures and the deadline audit. Tests use the
working Djex `63a23f58`; the committed dependency remains `4a4ed0fc`, and complete
native integration is still open.

## Verification

- Four real-kernel discovery cells pass: ordinary/contextual modes, each through
  namespace roots and explicit session names. Every cell retains exactly the
  generic fold, two constructors and an ordinary user `elim`. The session cases
  explicitly name the generated helpers and still exclude them.
- The strict native executable and test builds pass. All five existing provider
  discovery tests and four new deadline regressions pass. These are focused
  checks, not a new full 701-test integration run.
- The six original public Lean tree queries run against the rebuilt executable
  at unchanged provider, search and time limits. All observed provider names
  satisfy the original allowlist; every positive query discovers exactly the
  supplied fold and two constructors. The oracle still passes eight controls
  with 17 empty axiom inventories.
- The source distribution includes the discovery helper and portable tree
  fixtures. The initially ambiguous Cabal executable selector was corrected to
  the explicit package directory; the failed invocation is retained.

## Corrected tree outcomes

| Engine | Positive accumulator query | False control |
| --- | --- | --- |
| Djinn | No match; 39 false observations, zero inconclusive | Passes within the deadline; 194 actual false observations |
| Exference | Exceeds 90 seconds; 108 false observations, zero inconclusive | Exceeds 90 seconds; 446 actual false observations; failed cell |
| Both | Exceeds 90 seconds; 175 false observations and one inconclusive | Exceeds 90 seconds; 404 actual false observations; failed cell |

These results contain **zero accepted positive accumulator cells**. A bounded
miss or timeout is not a proof of uninhabitation. The inventory change alone does
not establish a causal performance improvement from elapsed-time comparisons.

The shared behavioral parser establishes actual predicate observations, even if
a command subsequently reaches its deadline. The tree fixture promised a
stronger acceptance rule but did not enforce that extra check. It now rejects
the production deadline message before accepting either a positive or False
cell; a successful prefix cannot override cancellation. Four focused regressions
cover false observations, an accepted prefix, completed rejection, and the
distinction between a configured timeout and an actual timeout event.

The [previous receipt's erratum](../../test-church/receipts/search-failures-retriage.erratum.json) corrects the earlier claim that
Exference and Both tree False controls passed. Both commands had timed out.
Their rejection observations remain valid, but **none of that earlier Lean
tree matrix's cells passes the complete inventory/deadline contract**. Original
receipts and captures remain byte-for-byte intact.

The new six-query run finished before the harness correction. The corrected
gate was applied to its exact hash-checked captures and to the earlier matrix;
this transcript audit is not presented as a second live synthesis run. The new
Djinn False cell passes both the original inventory check and the added deadline
check. The audit retains every original status beside the corrected status.

## Reproduction and remaining work

The [discovery runner](../../test-context/run_provider_inventory.py) compiles the actual production generator and
checks its emitted Lean inventories with the production Haskell parser. The
[tree fixture](../../test-recursive/tree-accumulator/README.md) retains the original type, 16 observations, fold-only value
inventory and search limits. Its `audit_deadlines.py` accepts one or more
`--receipt` arguments and a fresh `--output` directory; it verifies each original
capture's hash before applying the corrected gate.

The next priority-2 construction remains the function-carrier tree fold. A
state-transformer witness already expresses the requested behavior, so trace
its instantiation and scheduling before expanding recursion machinery. Keep
the recurring layered-provider integration deadline, bounded Haskell frontend
usability, and all 13 extended plus 19 explicit-default behavioral operations
open. This milestone does not alter their acceptance requirements.
