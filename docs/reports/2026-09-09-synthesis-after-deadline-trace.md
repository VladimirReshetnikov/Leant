# Further improvements after request-deadline and native-tree diagnostics

This September 9, 2026 assessment supersedes the execution order in the
[previous frontier report](2026-09-08-synthesis-frontier-retriage.md), while
preserving priorities 1–4 and their completion requirements. **Close the current
deadline validation gap, deliver the remaining public contextual frontend,
then pursue a bounded tree-search repair and the full Church behavior matrix.**
The tree diagnostic has now run; tracing the same query unchanged is no longer
the next delivery. No new synthesis acceptance is claimed by this report.

## What is accepted, and what has changed

- The [implicit-signature REPL increment](2026-09-08-implicit-root-scope.md)
  is accepted at canonical Djex `ca706427`: 361 tests in six complete affected
  suites and 350 signatures per Haskell engine. The vacuous-binder regression
  is resolved. One-shot commands, typed list output and broader binder and
  selection coverage remain open.
- The [completed native integration](2026-09-08-combined-native-integration.md)
  remains accepted at its recorded production revision and pinned Djex
  `bfc3692e`. Its 702-test result and ten passed gates do not certify the newer
  uncommitted backend or canonical Djex frontend revision.
- The uncommitted Leant deadline repair passes all three newly reproduced
  regressions and 705 unit tests. It applies one request deadline to annotation
  evaluation, payload encoding, sending and response handling. The sender is
  owned so a blocked Windows pipe can be released by retiring the backend.
  The original three cases failed; the fixed cases finish in about one second
  each. This is a validated local repair, pending native integration acceptance.
- Fresh native integration passed six method cases and their replay, then
  stopped at the method-control preflight: `run_controls.py` requires the old
  `Backend.hs` hash. **No control sessions ran.** This is an obsolete source pin
  exposed by an intentional edit, not evidence of a failed behavioral control.
  The seven later gates did not execute. Source and executable integrity held
  throughout the attempted integration.
- The completed original-bound native Exference tree trace captured all 61
  started requests, with no omitted records or dropped events. The query still
  timed out at 90 seconds, with 15 candidates falsified and none accepted.
  There were 78.65 seconds between the last parsed response and cleanup, with
  no new request. The independently replayed expression from earlier debug
  output was not submitted in this run. This points toward candidate generation
  or traversal; it does not identify a precise cost center, prove provider
  starvation, or establish that the deadline repair changed search behavior.

The [diagnostic receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/deadline-tree-retriage.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/deadline-tree-retriage.zip)
retain the failed and passing deadline runs, complete unit receipt, terminal
integration preflight failure, tree trace, source snapshots and uncommitted
patch. Invocation annotations are not typed-graph or kernel certificates.
The archive preserves local diagnostic evidence; it is not a release receipt.

## Revised delivery order

| Order | Delivery | Completion gate |
| --- | --- | --- |
| 0 | Close the request-deadline repair | Review the changed transport/capture contract, refresh the control fixture's source authority with provenance, and run every required native gate with frozen inputs. Preserve the preflight failure. Do not bypass the hash guard or treat unit and positive-method results as complete integration. |
| 1 | Finish public contextual output, P3 | Share the accepted typed rendering and scope rules with one-shot contextual commands, then typed list output. Cover applicable ordinary and named-`where` entrances, both Haskell engines, first/best/all selection, loaded providers and exact displayed definition/expression replay. Preserve original signatures, binder identity and dictionary payloads. |
| 2 | Bound the native tree search investigation, P2 | Measure cursor forcing, lane transitions and provider discovery around the request-free interval. Establish which work prevents progress before changing scheduling. Test any repair against the original three-mode positive/False matrix and exact full-type plus 16-observation replay. |
| 3 | Close missing Church behavior cells, P4 | Continue Djinn `maybeEither`, supplied-default selectors, nonempty reductions including `foldl1`, extrema and native-`Int` indexing. Classify each mode separately; synthesize and replay actual implementations, with completed negative controls. |
| 4 | Broaden contextual evidence, P3 | Derived Haskell methods and mixed Lean constructor/method inventories, followed by distinct equal-predicate dictionaries, conditional providers, superclass evidence and richer universes. Each increment needs exact source ownership and independent compiler/kernel checks. |

Order 0 is release closure for work already implemented. Orders 1–4 remain
bounded deliveries, not permission to let one difficult tree query block all
independent frontend or behavioral progress. Stop a tree diagnostic batch when
it has answered its stated question; if no repair is justified, preserve the
miss and continue the next delivery. Do not increase the original limits just
to make an acceptance case pass.

If measurement confirms lane starvation, consider resumable interleaving of
structural and provider search. Retain each lane's cursor, candidate identities,
remaining budget and common deadline. Discarding the structural remainder,
restarting it, or silently enlarging the search would change the contract.
Earlier failed scheduling experiments remain relevant regression evidence.

The P4 target is still **160 operation/mode cells**: all 13 extended and all 19
supplied-default operations across Haskell Djinn/Exference and Lean
Djinn/Exference/Both. Controls and exact replays are additional. This number
is a worklist size, not a current pass count. Lean partial cases continue to
use the agreed explicit default or inhabitance assumption. Type inhabitation
of a Church signature alone does not establish the intended behavior.

## Other ideas, re-ranked

| Idea | Disposition | Reason and evidence needed |
| --- | --- | --- |
| Reliable end-to-end deadlines and owned cleanup | Finish now | Three concrete defects are reproduced and locally repaired; release acceptance remains incomplete. |
| Exact displayed-output replay | Required correctness work | A checked internal term can still be printed outside the scope of its type variables or dictionary. Use the exact public output at the original signature. |
| Candidate identity plus phase timing | Promote narrowly for tree search | The request-free interval warrants search-side measurements. Correlate each candidate's own graph, lane, renderer, request and selection; report trace omissions explicitly. |
| Receipt freshness and a small machine-readable acceptance index | Promote alongside the next milestone | The stale backend pin and obsolete roadmap pointers are concrete maintenance failures. Retain immutable historical runs, record current revision/fixture/runtime identity and distinguish accepted, historical, miss, timeout, preflight-failed and unrun. Start with existing receipts, not a new framework. |
| Fair resumable lane scheduling | Conditional next search change | Advance only after timing identifies starvation. Preserve cursor progress, total budgets and candidate ownership; require both tree and accepted List/Church regressions. |
| Exact duplicate suppression | Defer pending a measured duplicate workload | Compare typed candidates including source environment, polymorphic selections and dictionary identity. Printed-text equality alone is insufficient. |
| More verifier batching, workers or transport optimization | Defer general tuning | The current tree evidence places the long interval outside any active request. Reopen only when a remaining workload measures repeated or expensive verification. |
| Counterexample-guided search, observation caching and semantic pruning | Defer | First establish repeated evaluations with the same candidate, environment and predicate. Finite agreement cannot justify general equivalence pruning. |
| Provider retrieval and relevance ranking | After admission and scheduling | First ensure a supported provider is admitted and its search lane runs. Measure recall as well as latency on realistic inventories. |
| General memoization and shared subgoal graphs | Defer | Require a profile showing equivalent repeated search work and a scope-safe key. A timeout alone is insufficient evidence. |
| General recursion, indexed/dependent synthesis and induction | Separate expansion | Introduce when a required example exceeds supplied folds and exposes concrete equality or termination obligations. |
| Lean-native engine rewrite, editor integration and additional platform tooling | Separate architecture/product milestones | These do not close the present public frontend, tree or Church behavior gaps. |

Priority 1 remains accepted within its documented elaboration fragment.
Ordinary structures, canonical Haskell Exference tree synthesis, native List
recursors and the accepted contextual fragments remain regressions. Native
tree synthesis remains unaccepted in all three modes. The broad rank-N and
impredicative synthesis goal remains open.
