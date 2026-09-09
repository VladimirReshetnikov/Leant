# Contextual constructors and polymorphic list output

Canonical Djex now constructs nonempty contextual lists through checked source constructors and retains the source signature when nested binders have been alpha-renamed. The documented list matrix checks both Haskell engines and the paired REPL mode, including exact dictionary observations and independent compilation of the displayed output.

## Changes

Djinn's contextual proof plans keep datatypes nominal to preserve dictionary identity. They previously lacked the constructor premises needed to turn a contextual method result into a nonempty list. An additional plan now offers visible constructors from the prepared datatype inventory through the existing checked provider-rewrite path. The original plan remains first. Both use the common search budget, and the constructor plan does not certify general non-inhabitation. Constructor-only plans are also available when the context is unused and there is no method-instantiation helper, including checked nested contexts. This does not relax recursive type expansion or expose hidden constructors.

The shared frontend also previously treated the parser's source-name hints as a complete map. Those hints intentionally omit some identities created by alpha-renaming repeated nested binders. One missing nested name therefore discarded the root signature, producing `HaskellGraphRootSignatureRequired` when a contextual candidate needed typed elaboration. The frontend now gives those nested identities fresh local names disjoint from source hints. Root binders still require their actual source spelling; the renderer still compares the complete signature against the candidate's own graph before importing its scope.

The list fixture now recognizes lambda and list expression output as well as parenthesized expressions. It retains the exact candidate text for replay. Both-mode checks require output from each engine. This corrects the extraction failure recorded in the [preceding diagnostic](2026-09-09-synthesis-after-native-contextual-integration.md); it does not rewrite a candidate to make the test pass.

## Acceptance

Strict builds pass with `-Werror` and one build job. All **2,385 tests in 16 complete suites pass**. The suite includes **90 positive/False behavioral query pairs**, two independently replayed wrapper results and two hidden-constructor rejection queries. Six additional positive/False query pairs construct lists without any exported constrained method, under both outer and nested contexts; their eight displayed results replay independently. Every suite has a complete inventory and a matching terminal pass count.

The fresh **80-query one-shot list matrix** compiles and evaluates **2526 displayed alternatives**. The earlier contextual one-shot matrix passes **64 queries and 5354 exact displayed replays**, four source-scope rejection guards and eight noninhabitation queries. Both Haskell corpora pass **350/350 signatures**, and extended Exference retains **13/13 operations**, one False control and 28 independent oracle controls at its original limits. These alternative counts are not counts of unique programs.

All recorded source and executable integrity checks pass. The [receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/contextual-list-output.json) and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/contextual-list-output.zip) retain test inventories, terminal logs, source identities, exact one-shot output and replay artifacts. Successful temporary modules from the named REPL tests are checked inside those tests but are not retained individually.

The behavioral REPL matrix covers five original signatures: explicit and implicit contextual lists; a function required to prepend the caller's method result while preserving its input tail; transport of a rank-N function into a list; and the same transport with a root name deliberately colliding with the generated-name prefix. Each runs in Djinn, Exference and Both, with first/best/all selection and expression/definition rendering. Positive queries and False controls use the same original 32-candidate window and 20,000-step/choice settings. Every displayed positive alternative is compiled and evaluated at the full requested signature.

An additional method-free fixture checks `forall a b. C a => b -> [b]` and `forall a b. b -> (C a => [b])` in all three REPL modes. It must construct a singleton from its term argument; independent replay checks both integer and Boolean elements. No constrained value provider is exported.

Separate wrapper tests require `Wrap [Token]` to contain the caller's method result and confirm that an abstract exported `Vault` does not expose its hidden constructor. These are bounded synthesis checks, not an impossibility theorem about the hidden type. The positive wrapper output is independently replayed.

The one-shot list matrix uses five signatures, two Haskell engines, four selection/ranking profiles and both output modes. It checks every displayed alternative at the original signature. Type-only queries may return empty lists, ignore arguments or select a valid closed instance. Their oracle allows those choices; named behavioral queries separately require the desired dictionary and list behavior. The existing contextual one-shot matrix remains a separate regression.

## Remaining scope and integration

This milestone closes the documented contextual list matrices, not arbitrary data construction or complete higher-rank search. Applicable named-function `where` one-shot entrances, kinded source binders and broader provider/dictionary evidence remain in scope. Native tree synthesis remains unaccepted in all three Lean modes. The Church behavior objective remains all 160 cells, with supplied defaults for partial Lean counterparts and negative controls/replays additional.

Leant's accepted dependency remains `3adfac5c57ad5e1bec77c598c647f6c8eb38e6e6`. This canonical Haskell change needs native integration against its exact published revision before that pin is promoted. Earlier native acceptance does not validate the new constructor and presentation changes.

Archive SHA-256: `266c6d10c5c30736bfac9d29182b64f66fc2b0cd7f57aaebc239fe0486732485`.
