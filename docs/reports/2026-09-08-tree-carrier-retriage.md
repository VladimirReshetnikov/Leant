# Further improvements after the fold-carrier experiment

> Follow-up: the [scoped function-carrier repair](2026-09-08-function-carrier-search.md) is now accepted
> in canonical Haskell Exference. It retains tree and Church behavior, with
> complete regression coverage. The experiments and pending validation
> described below are the earlier checkpoint; native integration remains open.

The next delivery is to finish validating the measured Exference fold-carrier
repair. The recurring native layered-provider timeout remains the release gate.
Exact Haskell output and the remaining Church constructions follow as bounded,
independent deliveries. Broader search and recursion refactors remain deferred.

This updates the [previous priorities](2026-09-08-post-integration-priorities.md).
It preserves original priorities 1–4 and their full acceptance scope. The
[evidence receipt](../../test-recursive/receipts/tree-carrier-retriage.json) and
its [archive](../../test-recursive/receipts/tree-carrier-retriage.zip) retain the
baseline trace, experimental source patch, exact candidate graphs and replay
source, successful manual acceptance, and failed focused tests. The experiment
is uncommitted production work based on Djex `c5706436`; the receipt identifies
the actual source by hash. Publishing this report does not promote that change
or advance Leant's committed dependency.

## What changed the triage

The baseline Exference trace creates a useful `s -> s` carrier branch at search
step 2, then prunes it at step 1,120 without exploring it. Its priority is
approximately -80.900067 at a -80.9 cutoff. The observed candidate file is
byte-for-byte identical to the original 1,024-candidate failed pool. This
establishes premature loss of an existing choice in this query. It does not
establish that every useful derivation follows this branch.

The experimental change prices an arrow goal using the introduction action and
the residual result type: lambda introduction binds its parameters without
constructing values of those types. Existing forall-introduction handling,
numerical settings, search limits, provider inventory and checking remain in
place. This is a general change to the cost estimate, so its regression surface
extends beyond this example.

The unchanged public Haskell tree fixture passes under the experiment. Among
1,024 exact source-checked candidates, indices 160 and 556 pass all 16
observations at the full signature:

```haskell
forall a s. (s -> a -> s) -> s -> Tree a -> s
```

Both implement the same useful composition, shown here with readable names:

```haskell
\step seed tree ->
  foldTree (\value state -> step state value)
           (\left right state -> right (left state))
           tree seed
```

This display is explanatory; the archive retains the exact rendered terms that
GHC checked and executed. All eight oracle controls pass. The replay evaluates
1,024 contradictory controls, with zero passing indices. Original limits remain
100,000 search steps, queue size 1,024 and the first 1,024 candidates. Source,
library, executable, input and process-capture integrity checks pass. Search
takes 24.39 seconds and independent replay 10.81 seconds in this run; these are
observations, not controlled performance comparisons.

The permanent regression is not yet accepted. Strict builds succeed and all
92 private Exference tests pass, but four of nine supplied-recursor tests fail:

- Three existing list cases fail with `HaskellGraphUnboundTypeVariable` after
  the fixture refactor switched their output from compatibility erasure to the
  typed renderer. This is an exposed rendering limitation under the expanded
  test path; it does not by itself demonstrate a search regression.
- The new tree test reaches replay, where GHC 9.12.4 panics with
  `schemeER_wrk: breakpoint tick/info index too large!`. Its generated fixture
  duplicates the observation expressions for every candidate. The separate
  public runner, which shares its observation predicate, succeeds. Factoring
  the unit predicate is the next experiment; its success remains unverified.

The complete canonical regressions, signature corpus, extended behavioral
corpus and native integration have not been run with this estimate. The
manual positive cell is valid bounded experimental evidence; it is not a
released capability or complete cross-engine acceptance.

## Revised delivery order

| Priority | Delivery and reason | Acceptance and stopping rule |
| --- | --- | --- |
| **Next** | **Finish the fold-carrier experiment.** A concrete trace and independently checked positive result justify finishing this repair. First make the permanent replay fixture tractable, preserving all observations and full signatures. Preserve the old list fixture contract while recording the stricter renderer gap separately, or fix that gap with its own focused evidence. | Pass the supplied-recursor regression, then the complete canonical suites, 350 signatures per Haskell engine and the affected extended behavior at unchanged limits. Only then consider production promotion. A remaining search regression requires a narrower justified repair or withdrawal; do not compensate by increasing budgets. Follow with tree acceptance in Haskell Djinn and Lean Djinn/Exference/Both. |
| **Release gate** | **Resolve the native layered-provider deadline and complete dependency integration.** The latest native unit run at working `63a23f58` remains 700/701. Exference's pure Haskell named-binary probe allocates 12.55 GB cumulatively; an isolated faster result is insufficient. | Attribute construction/forcing costs in the exact failing stage and preserve result ordering. Require the unchanged focused test, complete native unit suite, and affected context, method, recursor, nested-forall, whole-signature and extended matrices at the final dependency. Advance the committed pin only after that gate. A new engine estimate needs its own integration evidence. |
| **Then, independently** | **Make exact Haskell output reliably usable.** Complete implicit-root binder scope/order and ordinary contextual expression/definition output. Add the newly observed list graph-rendering cases to this delivery. | Exact displayed implementations compile at the original explicit or implicit signature, through ordinary queries and named-function `where` queries. Exercise nested quantifiers and contextual parameters. Compiler-checked erasure in an older fixture does not establish typed-renderer usability. |
| **Continue construction coverage** | **Complete the extended Church and supplied-default matrix.** Prioritize Djinn `maybeEither`, Exference `foldl1` and native-Int `at`, and transfer useful carrier constructions where the evidence supports it. | Keep all **13 extended plus all 19 explicit-default operations**, across Haskell Djinn/Exference and Lean Djinn/Exference/Both. Every accepted cell needs actual synthesis and independent full-type checking at the existing bounds. Distinguish exhaustion, timeout, replay failure and unexecuted cells. |
| **After bounded frontend delivery** | **Expand contextual source admission and selected evidence.** Start with derived Haskell method schemes and mixed Lean constructor/method inventories, then selected dictionaries for equal predicates, superclass/conditional evidence and richer universes in separate increments. | Preserve source identity, root binders and the selected payload through search, rendering and replay. Retain overlap guards until selected-dictionary transport is demonstrated. Increasing provider caps cannot repair source admission. |

The semantic auxiliary-provider filter is **delivered** and leaves the active
improvement queue. Its [four real-kernel discovery cells and deadline correction](2026-09-08-semantic-auxiliary-providers.md)
remain the authority. Current published Lean tree positives still fail; after
the filter, only Djinn's False cell meets the full fixture contract. The new
Haskell experiment does not change those Lean outcomes.

## Disposition of the other ideas

| Idea | Decision now | Trigger for promotion |
| --- | --- | --- |
| Search-cost estimates | Promote the specific introduction-aware experiment; defer a general tuning campaign. | A traced failure, improved original acceptance and clean regressions. One successful carrier example does not justify arbitrary weight changes. |
| Memoization, duplicate suppression or a shared subgoal graph | Profile within the layered-provider release gate; defer the architecture change. | Repeated equivalent work accounts for substantial measured cost, and keys can preserve scope, source identity and budget semantics. |
| Combined-engine streaming and cancellation | Investigate only the failing stage first. | A trace demonstrates avoidable waiting or work after an eligible result, with ordering, ownership and accounting preserved by the repair. |
| Counterexample-guided search and observation caching | Defer until useful constructions are reachable and repeated behavioral rejection dominates cost. | A representative workload demonstrates avoidable replay cost. Cache by candidate, environment and predicate; finite agreement is not semantic equivalence. |
| Provider relevance and large-environment retrieval | Defer scaling; retain correctness of admitted inventories. | Recall and latency measurements show useful supported providers being missed in realistic environments. |
| Test replay factoring | Do next as part of the tree regression. | The same candidate pool, all observations, contradictory controls and original deadline pass without the compiler panic. Do not reduce the fixture's semantic coverage. |
| More diagnostics | Keep targeted traces, exact failures and terminal statuses; no new framework. | A missing observation prevents a concrete decision. Preserve compiler panic, rendering failure and bounded search miss as distinct outcomes. |
| Worker counts and RTS tuning | Defer. | Controlled evidence identifies startup, GC or residency as the bottleneck. Cumulative allocation alone does not imply high resident memory. |
| General recursion, induction, indexed/dependent synthesis and invariant discovery | Defer broad expansion. | A concrete requested program cannot be expressed with the supported ordinary data and supplied folds and needs additional termination or equality machinery. |
| A Lean-native engine or editor/tactic product integration | Separate architecture/product work. | A concrete user workflow requires it and has kernel replay, environment and budget acceptance criteria. |
| Native Windows Length acquisition | Keep as a separate platform delivery. | Exercise acquisition, configured solver execution and independent replay in the actual Windows workflow. |

## Scope and publication boundary

The user-approved supplied default or inhabitance assumption remains the Lean
contract for partial source operations such as `head` and `fromJust`. Supported-
fragment elaboration has bounded acceptance; wider contextual usability and
construction coverage remain open. Finite behavioral tests and a signature
corpus do not prove semantic completeness of higher-rank inhabitation search.

This milestone publishes the revised priorities and preserved evidence in both
repositories, with root README links. Production engine and test edits remain
under validation. Leant's committed Djex pin remains `4a4ed0fc`; its working
dependency remains `63a23f58`. The wider implementation goal remains active.
