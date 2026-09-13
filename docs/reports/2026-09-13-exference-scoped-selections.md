# Exference preserves explicit lexical type selections

Exference now explores multiple legal lexical instantiations of a constrained provider and preserves the selected class arguments through independent checking. The canonical Haskell validation passes, including exact GHC execution of both choices for global providers and local rank-N callbacks. The new native Lean run also passes all 12 selection cases, all six actual False controls, and all 707 unit tests; its signature replay gates are still running. Leant's production dependency has not yet been promoted.

This closes the construction/reconstruction gap isolated by the [native diagnostic](2026-09-13-native-selection-diagnostic.md). It complements the earlier [Djinn source-selection repair](2026-09-13-scoped-source-selections.md). The [delivery re-triage](2026-09-13-synthesis-delivery-retriage.md) retains the pending constructor integration, reduction/extrema coverage, and exact bounded-search failures as separate work.

## Problem and resulting behavior

For a target such as `forall a b. (C a, C b) => Token`, a provider `forall p. C p => Token` can select either `a` or `b`. Neither the result nor a value argument determines `p`. Previously, Exference's search used a helper that accepted only a unique lexical assignment, so this query produced no candidates. The same problem affected a rank-N callback supplied as a local argument.

An enumeration-only experiment reached completed search terms, but the independent checker rejected them with unresolved constraint-only variables. Their erased expressions carried no information distinguishing `provider @a` from `provider @b`. Increasing search alternatives alone was insufficient.

The repair separates search choices from implicit inference:

- Search enumerates coherent lexical assignments within the existing matching guard. It keeps already checked alternatives when the guard ends. It never assigns a Given-side variable, imports an instance as a new Given, or inspects further matches beyond that guard.
- Implicit checker inference still requires uniqueness. A truncated matching run cannot certify a unique assignment, and an erased ambiguous expression remains rejected.
- A per-use expression annotation retains the selected direct class arguments. The checker reconstructs the original provider spine, captures its actual obligations in source order, and unifies those obligations with the annotation. It independently resolves each dictionary in the original lexical scope and seals the resulting graph.

Selections can accompany ordinary provider heads and visible type-application spines. An annotation cannot override an explicit incompatible type argument, change the provider's class, add a missing dictionary, or borrow a sibling's Given. The annotation supplies choices, not dictionary evidence or a certificate.

## Representation and API effects

The Exference expression pattern set gains `ExpSelect`. Its marker payload is separate from real local identities and erases to the same value expression. Structural scoring ignores the marker. Rewrites preserve it; eta contraction is disabled for annotated expressions so a marker cannot become a standalone value. The legacy traversal tests were updated to traverse this new wrapper.

The stable typed-query facade is unchanged. Consumers that exhaustively match the raw Exference expression patterns must handle `ExpSelect`. The checker error type also gains a refusal for selections applied to something other than a direct provider spine. Compatibility erasure does not itself encode an otherwise ambiguous choice; exact source output must use the checked graph and its retained type applications.

This increment does not remove the guard on arbitrary selection between hidden Haskell dictionaries with identical predicates. It selects class arguments and relies on unambiguous lexical evidence for those selected types. Broader equal-predicate occurrence selection and deeper source-admission work remain separate obligations.

## Canonical validation

GHC 9.12.4 strict builds use `-Werror` and one job. The final frozen run passes:

| Gate | Result |
| --- | --- |
| Existing cyclic-pattern preflight, extended with malformed selection arity | Pass |
| Focused selection, freshness, ambiguity, matching-guard and refusal tests | 10/10 |
| Public selected-dictionary cases | 4/4: both engines, global providers and rank-N local callbacks; generated implementations execute in GHC |
| Complete private Exference engine suite | 97/97 |
| Complete Exference suite | 515/515 |
| Complete integration suite | 156/156 |
| Church signature corpus | 350/350 in each Haskell engine, both generated corpora pass GHC checking |
| Scope probes | 50 per engine; generated positives pass GHC checking, negatives retain bounded-refusal labels |

Sources, test binaries and the controller remain unchanged throughout that run. No fresh complete CLI run is claimed by this receipt. Public library synthesis and exact GHC replay are covered; native integration has its own gates. No Church behavior cell is added by association.

## Retained unsuccessful attempts

The baseline global/local regressions both produce no candidates. The enumeration-only experiment records the independent checker's unresolved constraints and retains its temporary trace instrumentation separately from final source.

The first full validation exposes an eager-erasure regression: matching the compatibility view of a deliberately cyclic pattern list forces the list before the bounded arity preflight can reject it. The process ends with a memory-commit failure. The repair restores lazy projection over the shared expression representation. Selected class arities are also checked before traversing their argument types. The original adversarial case and the complete 515-test suite then pass. The unsuccessful run remains archived with its exact source snapshot.

## Reduction witness and evidence archive

A separate design check now compiler-checks the function carrier `R = (a -> a) -> a -> a` for both supplied-default `foldl1` and `foldr1` in Haskell and Lean. Lean also checks four closed examples, including nonassociative subtraction and empty-list defaults, and reports no axioms for either function. The earlier finite-model note records 18,744 observations; its generator is not included. These checks establish a usable typed witness, not synthesis reachability or general behavioral acceptance. The next reduction trace must determine whether the engine admits the carrier and can construct the required applications.

The [receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/exference-scoped-selections-2026-09-13.json) and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-church/receipts/exference-scoped-selections-2026-09-13.zip) retain the baseline, enumeration-only experiment, failed and passing full runs, changed source overlays, build logs, controllers, Church replay modules, and reduction witness checks. All 81 archive members were rehashed after packaging. The archive is 681,281 bytes with SHA-256 `36b6a98af333d8fc6972f762fba822d6a898672dbe0cec5aae466bd1583c4d81`.

The historical Church ledger remains 92 accepted, 15 attempted without indexed acceptance, and 53 without indexed evidence. Its 160 cells and the remaining source/interface/contextual obligations still define unfinished work; these counts are not a current-revision pass rate.
