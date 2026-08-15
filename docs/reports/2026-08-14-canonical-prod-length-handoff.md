# Exact canonical `Prod` Length handoff and offline query

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** The offline query boundary described here is
> now consumed by a nominal product-specific live ranking, post-verification,
> and presentation path. It reuses only the domain-neutral execution policy
> and common Djex session limits; product contracts, observations, evidence,
> failures, MRU state, and assessments remain distinct from scalar Length.
> Product startup configuration version 4 and contract-only version 6 remain
> deferred. See the
> [live binary-product Length ranking report](2026-08-14-live-binary-product-length-ranking.md).

## Outcome

Leant now has an additive checked entrance for the Djex
`finite-binary-product-spine-lengths/v1` domain. It accepts one
callback-verified Exference candidate only when the result root after the
serializer's existing `whnfR` normalization is saturated canonical Lean
`Prod` and both source-ordered fields are exact unary applications of the
configured finite spine. The resulting
product contract, checked candidate problem, and QF_LIA query are nominally
distinct from their scalar Length siblings.

The checkpoint stops at pure query construction and replay. It does not add a
live product worker, rank candidates with product evidence, or change any
configuration-file grammar.

## Exact source provenance

Lean elaboration distinguishes `Prod`, `And`, and `PProd`, but the historical
synthesis fragment represented all three with the same structural pair node.
That representation is sufficient for proof search and rendering but is too
weak to grant product behavioral authority. Leant therefore records an exact
`FLeanProd` marker only when the post-`whnfR` head is canonical `Prod` with
exactly two arguments. This intentionally admits reducible aliases only after
they normalize to `Prod`; normalized `And` and `PProd` continue to use the
generic product fragment.

Lean elaboration may emit unrelated info messages, including caller-chosen
text. The acquisition boundary therefore requires exactly one trimmed
`(goal ...)` serializer envelope after fatal/error precedence. Zero or multiple
matching envelopes fail closed before parsing, so an earlier forged
`lean-prod` payload cannot shadow the serializer's real structural result.

Structural consumers treat `FLeanProd` like the existing boxed pair: search
translation, schema equivalence, fitting, tuple rendering, specialization,
variable collection, and size accounting keep their previous behavior. Exact
fragment equality and equality-based premise deduplication deliberately retain
the distinct constructor, so an `And` or `PProd` fragment is not silently
reclassified as exact `Prod`. The marker is inspected for behavioral authority
only by the product Length handoff. That handoff peels the target's leading
arrows, quantifiers, instance binders, and
exact contexts, then requires the result root itself to be `FLeanProd`. It
also requires each field to be an exact unary application of the configured
spine family.

Consequently all of these fail closed:

- `And` and `PProd`, despite their structural pair shape;
- a scalar spine result;
- a product nested inside either result field rather than at the result root;
- either product field with the wrong family or arity; and
- a non-binary or otherwise noncanonical product representation.

The built-in `Prod` head is not entered into semantic-family provenance.
Leant resolves only the caller-configured spine family, zero constructor, and
step constructor from the exact retained translation bindings. No
`SemanticFamilyBinding` is fabricated for `Prod`.

## Shared authority, distinct domain

`prepareCheckedLengthSpinePairProblem` reuses the scalar handoff's authority
sequence, inserting only the exact product-shape gate after renderer
correspondence and before family/provider resolution:

1. recover the callback-accepted candidate's exact typed origin;
2. require unchanged source/search/engine/fit fragments, no premises, and an
   unchanged context-free request goal;
3. recheck the exact renderer alternative and callback text under the selected
   candidate-case policy;
4. require the normalized canonical `Prod` root and both configured-spine
   fields;
5. resolve the configured spine and every assumed provider law through
   retained Exference provenance;
6. convert the same target-role/candidate-case pair into Djex's closed
   `LengthInterpretationPolicySource`; and
7. seal the same inventory, spine model, and provider assumptions through
   `sealLengthSessionWithInterpretationPolicy`.

The pair path then uses
`sealLengthSpinePairContractInSession` and
`sealLengthSpinePairTypedCandidateProblemInSession`. Reusing the scalar
provider and session authority does not mean casting scalar evidence: Djex
wraps the checked inventory and uses product-specific contract, candidate,
encoding, problem, behavioral-envelope, and query identities.

`LengthSpinePairHandoffRefusal` retains product-specific failures while
nesting the established scalar handoff refusals. This leaves the scalar public
error type and constructor ordering unchanged.

## Concrete library example

For a callback-verified candidate corresponding to
`fun xs => (xs, xs)` at a goal such as
`List Nat → Prod (List Nat) (List Nat)`, the passive contract can state that
both result lengths equal the single observed input length:

```haskell
pairContract = LeanLengthSpinePairContract
  { leanLengthSpinePairContractSpine =
      LeanLengthSpineIdentity "List" "List.nil" "List.cons"
  , leanLengthSpinePairContractTargetArgumentRoles =
      Just [LengthObservedSpine]
  , leanLengthSpinePairContractCandidateCasePolicy =
      LeanLengthCasesRejected
  , leanLengthSpinePairContractSource = LengthSpinePairContractSource
      { lengthSpinePairContractPrecondition = LengthTruth True
      , lengthSpinePairContractPostcondition = LengthAll
          [ LengthEqual
              (LengthVariable
                (LengthSpinePairResult LengthSpinePairFirst))
              (LengthVariable (LengthSpinePairInput 0))
          , LengthEqual
              (LengthVariable
                (LengthSpinePairResult LengthSpinePairSecond))
              (LengthVariable (LengthSpinePairInput 0))
          ]
      }
  , leanLengthSpinePairContractProviderLaws = []
  }

queryResult = prepareCheckedLengthSpinePairQuery pairContract verified
```

The `verified` value must come from Leant's existing callback-verification
boundary and carry the exact typed Exference origin. Constructing the passive
contract cannot make a candidate eligible. The nested `Either` returned by
the adapter preserves the handoff-refusal boundary separately from bounded
SMT-query construction errors.

## Offline query and replay boundary

`Leant.Synth.Length.Adapter` exposes the opaque specialization
`CheckedLengthSpinePairQuery` and the bounded entrances
`prepareCheckedLengthSpinePairQuery` and
`prepareCheckedLengthSpinePairQueryWithLimits`. They construct Djex's
canonical QF_LIA product query without launching a process. The query retains
its exact checked product problem and fingerprint while deriving only the
bounded public check bytes, ordered input symbols, and optional input-value
request needed by the pure boundary.

Djex's product-specific validation and replay entrances independently evaluate
decoded model bindings, saved input vectors, the canonical all-zero origin, or
an explicitly bounded finite input box against the query-owned problem. A
counterexample becomes evidence only after exact behavioral association
succeeds. It remains model-relative finite-spine evidence, conditional on any
assumed provider laws used by the candidate. It is not a Lean execution,
kernel theorem, source-level behavioral proof, provider-law validation, Z3
attestation, or pruning permission.

In particular, a raw solver status has no authority. `sat` without a decoded
and independently replayed violating model is heuristic only; `unsat` without
query-owned bounded validation proves nothing at this boundary; and `unknown`
is likewise not evidence.

## Compatibility and work deferred at this checkpoint

This checkpoint makes no scalar protocol or identity change. Existing scalar
Length query bytes, live session/worker types, MRU input bank, origin-before-
live orchestration, unsat-triggered scalar box validation, presentation, and
stable ranking remain as they were.

At the time of this offline checkpoint, the following product work remained
deliberately deferred:

- a separately versioned live product worker/session protocol;
- product ranking and presentation semantics;
- product integration with replay banks, origin probes, or live-triggered box
  validation;
- a startup or command-local product configuration grammar; and
- any automatic inference of a product behavioral contract from Lean syntax.

Product queries must not be routed through the existing scalar live envelope
merely because their low-level check/request bytes can share QF_LIA shapes.
Their checked domain, problem association, and fingerprint are different.

The later live-ranking checkpoint resolves the live execution, ranking,
replay-bank, origin, input-box, and presentation items through nominal
product-specific APIs. It deliberately reuses the common capability-probed
Djex live session instead of introducing a second worker type; the common
session budget grants no scalar-to-product evidence conversion. Product
startup/command configuration and automatic contract inference remain
deferred.
