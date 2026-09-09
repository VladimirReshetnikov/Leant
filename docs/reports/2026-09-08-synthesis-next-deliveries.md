# Further improvements after the native recursor gates pass

This September 8, 2026 re-triage, updated after terminal integration, reorders the remaining work under priorities
1–4. The full goal remains open. The useful next work is a bounded transfer
check for tree folds, completion of public Haskell frontend behavior, and the
remaining Church behavioral cells. Broader search and architecture changes
need a specific failing workload before they enter that queue.

## Evidence behind the change

The [completed native integration](2026-09-08-combined-native-integration.md)
now records all ten terminal gates passing at Leant production revision
`43f1bc11` with Djex `bfc3692e`. Leant pins that exact tested dependency.
The [terminal receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/combined-native-integration.json)
and [archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/combined-native-integration.zip)
retain 3,736 hashed artifacts plus the manifest. Every member was rehashed;
the archive SHA-256 is
`ac464ba0f8d35a1095bf5bed2c59e2e8961660502e345be703022700ad2d87c9`.
The earlier nine-gate checkpoint remains preserved separately.

| Gate | Recorded result |
| --- | --- |
| Complete Leant unit suite | 702/702; retained passing v2 run on unchanged production and executable bytes |
| Global methods and controls | Six method cells with exact replay; nine fresh method-control/cache sessions |
| Local contexts | 39/39, including 18 exact output cells and the refusal/control cases |
| Simplification | 15 queries: six candidates, three false controls, six inconclusive controls; independent candidate/proof replays |
| Native List recursors | **12/12 at the original limits**: nine exact full-type candidate replays and three completed False controls across Djinn, Exference and Both |
| Extended Lean Exference behavior | **13/13**, exact full-type replays and one actual False control |
| Nested-result foralls | Nine cells: six exact outputs and three actual False controls |
| Native Djinn signatures | **350/350**, independently replayed with empty candidate axiom inventories |
| Native Exference signatures | **350/350**, independently replayed with empty candidate axiom inventories |

The native recursor timeout repair now has a complete matrix behind it. All
nine replayed recursor implementations, their observation proofs and `List.foldr`
have empty reported axiom inventories. The combined verifier preserves its
original proof fallback; simplification and extended-corpus proof inventories
retain their existing separate policies. Do not generalize the empty recursor
inventories to every proof in the project.

Unit and positive-method results come from the preceding v2 run. Only three
trace-control fixture files changed after the positive-method run; that driver
imports or executes none of them. The new control sessions exercise those
changes. The final Exference signature gate and final input-integrity check
both pass, completing aggregate integration and allowing promotion from
`4a4ed0fc` to the tested `bfc3692e` dependency. The earlier checkpoint's
running-parent snapshot remains historical evidence. Failures remain in the earlier
[combined-verification report](2026-09-08-combined-behavioral-verification.md).

## Execution order

| Order | Delivery | Concrete acceptance |
| --- | --- | --- |
| 1 | Transfer the accepted function-carrier construction | Run the prepared native tree matrix once at its original bounds, and recheck Haskell Exference `foldl1` once. Require actual synthesis, exact full-signature replay, all original observations, and completed False controls. The tree also needs its provider, axiom and termination checks. Haskell Djinn tree remains a separate known miss. |
| 2 | Close the Haskell frontend gaps in separate increments | First implicit-root scoping, then one-shot contextual commands, then typed list output. Exercise ordinary and named-`where` public entrances in both engines; compile exactly what is displayed at the user's original signature. Preserve binder order, nested forall scope and dictionary payloads. |
| 3 | Finish the full Church behavioral matrix | Execute remaining extended cells and explicit-default groups. Start with concrete misses such as Djinn `maybeEither`, nonempty reductions and native-`Int` indexing. Keep all 13 extended and all 19 defaulted operations across five engine/language modes in the register. |
| 4 | Broaden contextual evidence | Admit derived Haskell method schemes and mixed Lean constructor/method inventories, then preserve distinct selected dictionaries for equal predicates. Conditional/superclass evidence and richer universes follow as separately checked extensions. |

The transfer checks are short investigative deliveries, not prerequisites for
all frontend and Church work. If an original-bound query still fails, record
whether construction, scheduling, rendering or verification caused it; trace
one concrete derivation before proposing a repair. Continue the next independent
batch instead of repeating an unchanged failed run or expanding its budget.
Heavy validation remains serialized with frozen inputs.

Implicit-root support needs particular care: internally inserting `forall`
does not make its variables lexically scoped in a displayed Haskell right-hand
side under the original implicit signature. Any expression-level binding
solution must work with the supported GHC and behavioral worker, preserve
written binder order, and be replayed without rewriting the requested signature.
Prepared probes are not implementation or compiler acceptance.

The complete behavioral target contains **160 operation/mode cells**:
32 operations across Haskell Djinn/Exference and Lean Djinn/Exference/Both,
with controls and replay obligations additional to that count. Some are already
accepted at recorded revisions. This is a worklist size, not a claim of 160
missing or passing cells. Type inhabitation for the 350 Church signatures does
not establish the requested behavior.

The 19 supplied-default identities remain explicit:

- Selectors: `head`, `last`, `fromJust`, `fromLeft`, `fromRight`, `atKey`.
- Nonempty reductions: `foldl1`, `foldr1`, `reduce`.
- Extrema: `maximumBy`, `maximumOn`, `minimumBy`, `minimumOn`, `minMaxBy`,
  `minmaxElement`, `maximum`, `minimum`, `minMax`.
- Native-`Int` indexing: `at`, including negative indices.

Keep the original partial signatures separately classified. Their total Lean
counterparts use the agreed explicit default or inhabitance assumption.

## Disposition of other ideas

| Idea | Decision and promotion criterion |
| --- | --- |
| Additional verification-request reduction | Keep the delivered combined certificate and its controls as regressions. The recursor matrix no longer justifies making this the next optimization. Reopen it only for a measured remaining query. |
| Exact duplicate suppression in best output | Next performance candidate after frontend correctness. The preserved long-running fixture repeats compatibility text, but suppression must compare typed evidence, source identity and selected dictionaries. Demonstrate improvement at the original failing settings without changing observable selection. |
| Search diagnostics | Add only the observation needed to distinguish a missing construction from a delayed branch in the current failed cell. Preserve budget charges and bounded trace omissions. |
| Counterexample-guided search, observation caching and semantic pruning | Defer broad work. Require repeated exact candidate/environment/predicate evaluation as measured evidence; finite agreement alone cannot establish semantic equivalence or justify pruning. |
| Provider retrieval and relevance ranking | Finish supported provider admission first. Promote retrieval when a realistic inventory demonstrably excludes a useful supported provider; measure recall and latency together. |
| General memoization, shared subgoal graphs, worker/RTS tuning | Defer until a current profile identifies equivalent repeated work or a specific CPU, memory or transport cost. Printed duplicates and response-wait totals do not establish either. |
| General recursion, induction and dependent/indexed synthesis | Defer until a required program exceeds the supplied-fold approach and exposes concrete equality or termination obligations. |
| Lean-native engine rewrite, editor/tactic integration, native Windows Length acquisition | Separate architecture, product and platform milestones with their own requested workflows and acceptance criteria. They do not close the remaining rank-N frontend and Church behavior gaps. |

Priority 1 stays accepted within its documented Haskell elaboration fragment.
Accepted provider filtering, ordinary explicit-forall contextual REPL output,
canonical Exference tree synthesis and bounded combined verification leave the
implementation queue and remain regressions. Broader frontend coverage remains
under priority 3; the original priorities and their completion requirements are
unchanged.
