# Synthesis delivery re-triage: coverage, scoped evidence and bounded search

The next improvement should advance the missing Church behaviors. Build the complete receipt-derived coverage ledger first, then deliver small behavior batches while keeping contextual-constructor acceptance and dictionary-selection repair as separately tracked work. The expanded constructor matrix must no longer be a prerequisite for every independent delivery. This changes the execution order in the [previous assessment](2026-09-12-synthesis-after-contextual-constructor-probes.md); it preserves the active priorities 1–4 and their full completion requirements.

## Evidence behind the change

The published baseline remains the [accepted native integration](2026-09-12-contextual-list-native-integration.md): ten gates, 705 native unit tests and both 350-signature kernel replays, with Leant using Djex `c1ad560e`. Those results belong to their recorded revision. They do not validate the subsequent dirty working trees.

The [expanded constructor diagnostic](2026-09-13-contextual-constructor-frontier.md) passes 17 of 21 positives and all six actual False controls. It exposes three obligations, rather than one undifferentiated constructor problem:

| Boundary | Observed failure | Appropriate next step |
| --- | --- | --- |
| Djinn method-and-tail composition | The required program is absent from the original 32-candidate prefix. | Trace the exact captured request through proof construction, candidate accounting and source reconstruction. Establish which branch or rule prevents the composition from reaching the prefix. |
| Djinn nested dictionaries, also affecting Both | Source reconstruction reports `ambiguous lexical Given type instantiation`. | Preserve the actual selected type arguments and lexical dictionary occurrence through erasure and reconstruction. Retain the ambiguity guard when evidence is absent. |
| Exference nested dictionaries | Seven verified candidates fail the observations before the original step/queue limits stop search. | Investigate its search path independently. A Djinn source-evidence repair is not evidence that this search miss is solved. |

The previously proposed exact native capture is now available locally. It includes the abstract list/element types, qualified method, polymorphic nil/cons values, competing zero/successor values and empty provider assignments. The canonical regression using this world reproduces the tail miss; the earlier simplified fixture did not. This makes environment fidelity an immediate requirement for future search experiments.

Two further local experiments fail that captured regression: enabling the existing composition-priority traversal for the contextual plan, and exposing independently checked derived values with explicit proof-cost charges. The latter builds with `-Werror`, but the focused test still fails at 32 candidates. Its output includes a method-derived singleton that ignores the supplied tail. That is useful diagnostic evidence, not the required behavior. The priority-traversal experiment has been reverted; the derived-value experiment remains uncommitted and unaccepted at this assessment. These local logs are not a new archived acceptance receipt:

- Djex `dist-newstyle/contextual-polymorphic-priority-v1.log`.
- Djex `dist-newstyle/contextual-polymorphic-derived-build-v2.log`.
- Djex `dist-newstyle/contextual-polymorphic-derived-v2.log`.

The complete native unit run remains 707/709, followed by fixes and two passing focused source-wiring checks. A fresh complete 709-test run is still required for a release. Neither that requirement nor a green build supplies missing behavior coverage.

## Revised delivery order

These are execution priorities, not a renumbering or reduction of the original implementation goal.

| Order | Deliverable | Acceptance and stopping rule |
| --- | --- | --- |
| 1 | A complete, small Church behavior ledger. | Enumerate exactly 160 distinct operation/mode keys. Link evidence by source revision, fixture, limits and runtime identity. Record unrun, refused, bounded miss, reconstruction failure, replay failure and accepted outcomes separately. Keep historical acceptance distinct from current validation. Do not fill cells from signature tests or supporting constructor probes. |
| 2 | Missing Church behaviors in small independent batches. | Start with Haskell Djinn `maybeEither` and supplied-default selectors/nonempty reductions; order extrema and native-`Int` indexing from their actual failures. For each batch require live synthesis, original types/providers/limits, observations, actual False controls and independent replay of exact displayed output. Record the cause of a miss before moving to the next independent batch. |
| 3 | A bounded contextual-constructor release, without hiding expanded failures. | Define the supported boundary explicitly and run its complete acceptance matrix plus affected regressions. The six singleton probes alone are insufficient. Retain all four expanded failures in the register. A smaller release is permissible only if its unsupported cases have explicit, checked behavior and the release makes no broader claim; the full 21-positive target remains open. Publish canonical Djex first, then validate and promote that exact Leant dependency. |
| 4 | Preserve scoped provider selections through source reconstruction. | Carry the proof's chosen type instantiation and dictionary occurrence as checked evidence, including alpha-renaming and nested scopes. Test distinct outer/inner payloads, equal-predicate dictionary occurrences, wrong-scope selections and missing-evidence refusal. Require exact full-type replay. Do not replace a scoped choice with a type hole or relax ambiguity rejection. |
| 5 | Finish public query access, then broaden provider evidence. | Complete applicable named-function `where` one-shot entrances and kinded Haskell binders using existing parsing/evidence paths. Add derived methods, conditional/superclass dictionaries and broader Lean universes as separate increments with dedicated fixtures. Haskell kinds and Lean universes are distinct obligations. |

Independent work here means independent dependencies, not concurrent heavy builds. Keep one build/runtime owner and freeze each validation run's inputs. Before any implementation release, remove ineffective experiments or give their retained parts an independently demonstrated purpose, run the appropriate complete suites and preserve the accepted baseline.

## Other improvements reconsidered

| Idea | Revised decision | What would justify promotion |
| --- | --- | --- |
| Exact native-to-core reproduction | Promote now as a small diagnostic tool. The simplified fixture concealed the actual miss. | Capture the real environment, binder order, providers, assignments, strategy and limits; verify that the reduced regression reproduces the public failure. The first saved preparation dump used DepthFirst, so it must not be described as a complete Interleave request capture. |
| Candidate accounting and provenance | Promote only enough to explain the current 32-candidate failure. | Relate raw proof work, emitted groups, reconstructed variants and verified observations to stable scoped identities. Distinguish a missing derivation from work lost to duplicate candidates or reconstruction. |
| Search ordering, fairness and derived-value rules | Require a causal trace before another experiment. Several ordering variants have failed the real fixture. | Show the useful branch, the point where it is delayed or unavailable, and improvement at unchanged original bounds without loss of proof accounting or existing behavior. A scheduler redesign is not yet justified. |
| Complete coverage index | Immediate delivery infrastructure. | The 160-key ledger above, with no duplicate keys or blended pass rate across incompatible revisions. Keep the implementation small; a general orchestration framework is unnecessary. |
| Public explanations of unsuccessful search | Add when touching the corresponding failure path. | Report unsupported source, bounded exhaustion, reconstruction failure and verification failure accurately. A bounded miss must not be presented as impossibility. |
| Exact replay and negative controls | Continue as release requirements. | New emitted syntax or evidence forms require matching replay coverage; passing examples alone do not prove universal behavior. |
| Duplicate suppression and observation caching | Still conditional, not a default next optimization. | Measure repeated equivalent work and establish keys including lexical scope, selected type arguments, dictionary evidence, environment and predicates. Printed equality is insufficient. |
| Provider ranking and larger inventories | Defer broad changes. | Demonstrate lost recall after source admission and evidence reconstruction. Retain the existing targeted session-method preference while testing constructor enrichment. |
| Native tree investigation | One bounded attribution batch at a stable milestone. | Correlate discovery, candidate forcing, graph checking, rendering and backend requests while preserving the original observations and False controls. Record an unresolved result and return to the behavior queue if no cause is established. |
| More verifier workers, transport/RTS tuning, general memoization | Defer. | A measured bottleneck or repeated equivalent subproblem with safe scope keys; end-to-end latency alone is insufficient. |
| General recursion, induction, dependent/indexed synthesis, Lean-native engine | Separate future expansions. | A required example that existing data representations and supplied folds cannot express, with termination and equality obligations identified. |
| Editor integration and additional platform tooling | Later product work. | Stable public command semantics and broader accepted practical coverage. |

## Completion boundary

The full target remains **(13 extended + 19 supplied-default operations) × (2 Haskell engines + 3 Lean modes) = 160 behavior cells**, with controls and independent replays additional. This is the size of the target, not a count of missing cells. The agreed Lean counterparts of partial operations use supplied defaults or inhabitance assumptions. Named-function-plus-`where` syntax remains the public behavioral interface.

The main change in this re-triage is to stop expanding a single acceptance task indefinitely. Preserve its exact failures, deliver independent coverage, and return with evidence-driven repairs. Stable milestones still require current root READMEs and pushes to `origin/main` in both repositories. This assessment delivers documentation only; it does not accept the local code experiments, promote Leant's dependency or close the broader implementation goal.
