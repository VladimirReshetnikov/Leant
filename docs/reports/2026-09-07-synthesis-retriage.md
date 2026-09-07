# Synthesis re-triage: Leant integration and remaining capabilities

This 2026-09-07 update preserves the active goal to implement priorities 1–4
from the [accepted roadmap](../../lib/Djex/docs/reports/2026-09-06-synthesis-next-priorities.md).
The shared [implementation and acceptance checklist](../../lib/Djex/docs/reports/2026-09-07-synthesis-priorities-1-4.md)
and [execution recommendation](../../lib/Djex/docs/reports/2026-09-07-synthesis-retriage.md)
are maintained in the pinned Djex dependency.

## Current boundary

Leant `aab110e99e3c3d96549a05d3975b26bea93dc6ef` pins Djex
`6890bb5a8a56902c2baf137581e23c25a376fad0`. Integration of the Haskell
elaboration checkpoint is accepted at the receipt boundaries below. First/best
selection of a repaired candidate remains outstanding.

The newer working integration pins Djex
`3ce26cfd966ea4da2300028880c71ddaae50596d`. Djinn now passes all eight ordinary
recursive-data behavioral queries and independent Lean replay, with sixteen
empty axiom inventories and one actually falsified control. The
[`test-recursive` runner](../../test-recursive/README.md) covers `null`,
`headOr`, `tailOr`, shallow tree inspection, aliases, a unary tuple field,
an `unconsOr` pair, and two independently typed inputs. Library and named
provider discovery are disabled; partial cases use explicit defaults.

The [successful Djinn receipt](../../test-recursive/receipts/djinn-cases.json)
is retained from `dist-newstyle/recursive-acceptance/djinn-v1/results.json`. It records a
1,024-candidate/verification window, 100,000 choices/steps, interleaving,
a 90-second command deadline, exact displayed terms, and unchanged source
and executable hashes. These are finite observations, not universal laws.

The [mixed-engine receipt](../../test-recursive/receipts/other-engines-incomplete.json)
at the same source revision failed; its original location is
`dist-newstyle/recursive-acceptance/other-engines-v1/results.json`.
Exference did not find `tailOr` within 100,000 steps and timed out on the
tuple-payload case. Both also timed out on that payload despite the successful
Djinn-only result. The failed run performed no independent kernel replays.
Canonical Djex has an unaccepted fix in progress for optional recursive input
splitting and finite payload inspection. It also exposed an unused-binder
graph projection mismatch and the narrower graph boundary that accepts only
zero/step recursive cases returning the scrutinee's type. Extend declaration-
backed complete-case evidence, including finite tuple fields, while retaining
exact association, exhaustiveness, and lexical scope. Search improvements alone
cannot close this evidence gap.

The strict Leant build passed at the corrected dependency revision. A full
post-correction boundary run remains required: the earlier run had 55 failures
from missing fake-Z3 setup and two real positive-construction-bound failures.
Djex `3ce26cfd` fixes the latter by enabling case plans only when recursive
types occur negatively. The Djinn-only live receipt does not close the full
integration gate.

The initial positive GHC repair fixture exercises a graph-rendered impredicative
let. A subsequent public Exference query now demonstrates live repair under
`all` selection, exact display and independent GHC replay, and rejection of the
same repaired expression by a false predicate; see the implementation checklist.
The inspected live `reverse` failure had no source graph and therefore could
not authorize an annotation retry. Keep those two failure classes separate.

## Delivery order

The earlier accepted elaboration integration advanced the dependency to
`6890bb5a8a56902c2baf137581e23c25a376fad0`, including the Haskell elaboration
renderer, behavioral retry, and Exference implicit local graph evidence.
The GHC 9.12.4 `-Werror` build passed for `exe:leant` and
`test:leant-synth-tests`. All 615 Leant boundary tests passed in 256.23 seconds.
The executable and source hashes remained unchanged during that test run.
The [unit receipt](../../test-church/receipts/unit-elaboration-integration.json)
records source and executable hashes. The strict build log is
`dist-newstyle/priority-elaboration-integration-build.log`.
The [live behavioral receipt](../../test-church/receipts/behavior-elaboration-integration.json)
passed all 18 cases: the existing six operations under Djinn, Exference, and
Both, with an additional `where False` rejection control per engine mode.
Independent Lean 4.32.0 replay accepted the exact displayed implementations,
their predicates, and the oracle controls; all 69 recorded axiom inventories
were empty. The executable remained unchanged throughout the run. Settings
were a 65,536 candidate/verification window, 500,000 Djinn choice points,
100,000 Exference steps, interleaving, and a 90-second command deadline.
This validates the existing six-operation corpus at this dependency revision;
it does not complete priority 4's broader corpus.
This is integration evidence for the dependency checkpoint; remaining priority
1 acceptance and priorities 2–4 below still apply.

1. **Close Exference case parity and full Leant integration.** Retain the eight
   accepted Djinn cases; fix Exference's supplied-list default and unary tuple
   field, with complete graphs and actual Haskell execution. Require all eight
   cases in each engine mode, independent Lean replay, false controls, and the
   full boundary suite with its fake-Z3 helper configured. Preserve the existing
   positive-only constructor bounds. Check Both explicitly: a slow engine has
   already delayed an otherwise accepted Djinn result beyond the deadline.
2. **Close priority 1's remaining acceptance.** Require live first/best
   selection of a repaired candidate, exact checked/displayed text, retained
   missing-authority and scope controls, and the original resource bounds.
   Preserve the accepted all-selection fixture. Integrate and validate any
   further shared changes; integration of the current checkpoint is done.
3. **Deliver priority 4's bounded Lean simplification.** After decision checks
   for the assertion and its negation, attempt bounded simplification. Require
   a complete kernel proof, retain axiom inventories and the command deadline,
   and keep false and inconclusive outcomes distinct.
4. **Deliver priority 2's supplied folds/recursors.** Use generic recursion
   structure to target operations such as `map`, `append`, and `length`, with
   checked source evidence and termination guarantees. Add behavioral corpus
   cases alongside this work.
5. **Implement priority 3's contextual evidence.** Start with forwarding and
   dictionary-independent bodies under lexical givens, then methods,
   conditional providers, and superclasses. Retain identities and scoped
   obligations throughout Djinn's provider projection and graph checking.
6. **Close priority 4's full behavioral corpus.** Finish naturals,
   options/eithers, folds, conversions, and all 19 supplied-default cases.
   Begin this coverage during earlier deliveries; preserve explicit defaults
   or inhabitance assumptions and independent false controls.

None of the four priorities is complete. Moving the smaller simplification
delivery earlier changes scheduling, not the required contextual capability.
Keeping the active cross-engine case failures first does not authorize postponing
the small selection-mode closure until after general recursive synthesis.
All test results above are inspected prior receipts, not tests rerun for this
documentation update. The dependency's linked execution report reflects its
pinned checkpoint; this companion records the newer canonical-worktree triage.

## Why these boundaries matter in Leant

[`ExactFamilyPlan`](../../src/Leant/Synth/Engine.hs) now documents Djinn's
bounded positive recursive construction and checked one-layer input cases.
The same module's `djinnRecursiveProjection` uses `EraseProviderContexts`.
Context erasure remains a boundary to address explicitly; successful ordinary
input cases do not establish contextual Djinn synthesis.

[`Leant.Synth.Behavioral`](../../src/Leant/Synth/Behavioral.hs) currently uses
`by decide` for the proposition and its negation. Simplification is proposed
work. A failed tactic must never be converted into a false verdict or a proof.

Native Windows Length support remains a separate platform milestone:
[`Acquire.hs`](../../src/Leant/Synth/Length/File/Acquire.hs) deliberately returns
`LengthFilePlatformUnsupported`. Its acceptance needs acquisition, configured
solver execution, and independent replay together.

Promote the observed Both-mode delay into the current case acceptance. Fix the
concrete Exference search cases first, then change scheduling only if the delay
persists. Measure cold startup, first accepted result, search work, checking
cost, and memory before choosing other performance changes. Semantic provider retrieval is a
useful later scaling investigation when a real query misses a relevant
provider. Shared subgoal graphs, persistent caches, internal cooperative
search, dependent/indexed refinement, and induction remain behind the current
capability work. Native tactic integration and isolated-worker production
routing are separate product/integration milestones with their own acceptance.
Keep failure diagnostics and reproducible capability receipts within the
current deliveries: distinguish graph absence, compiler rejection, behavioral
falsehood, inconclusive checking, and search exhaustion, and retain settings,
source revisions, exact emitted-source replay, and negative controls.

The older future-directions reports remain design references; their claims
about missing typed graphs must be reconciled with the current implementation
before using them as a backlog.
