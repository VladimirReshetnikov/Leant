# Boxed polymorphic values: the next source boundary

The bounded `length` comparison is complete and did not isolate a constructor-field defect. The next source baseline has a checked Lean implementation, but the published contextual entrance refuses its higher-universe nominal parameter before search. This promotes exact nominal declaration universe signatures as the immediate prerequisite for the selected-polymorphic-type milestone.

This is diagnostic evidence, not a new synthesis acceptance. The [contextual binder-universe release](2026-09-14-contextual-universe-acceptance.md) remains the accepted native baseline.

## Completed length comparison

The private Djinn fixture compares a direct recursive counter with the same counter wrapped in a second datatype. It looks for a particular normalized fold expression in the returned candidates, preserving the original source goal separately from the implicitized search goal. Each case has an independent limit of 65,536 raw proofs and 500,000 choices.

The first attempt compiled successfully but rejected the fixture before search because it incorrectly supplied a leading explicit forall as the prepared search goal. The corrected fixture uses the same opening procedure as existing source-aware tests. Its strict build passes, and both cases run to `ChoicePointLimitReached` without the expected normalized witness. Their first twelve candidates and completion records are retained. Neither case was skipped because the other missed.

This result does not distinguish the wrapped case from the direct case, and it does not prove the absence of every behaviorally matching implementation. It therefore supplies no causal basis for adding constructor-field carriers. Do not enlarge the limits, reopen the failed carrier variants, or claim the Lean Djinn `length` cell has been closed. Resume that implementation only when a different trace identifies a specific lost step. The prepared checkout has no production changes; the diagnostic fixture is not added to the default published unit suite.

## A public query that needs a polymorphic type argument

The new baseline uses these declarations:

```lean
class SelectedPoly.Dictionary (α : Type) where
  tag : Nat

structure SelectedPoly.Box (α : Type 1) where
  value : α
```

Its full signature is:

```lean
∀ A : Type, [SelectedPoly.Dictionary A] →
  (∀ β : Type, β → Nat) →
  SelectedPoly.Box (∀ β : Type, β → Nat)
```

The independent reference `fun (A : Type) [d : SelectedPoly.Dictionary A] payload => ⟨payload⟩` passes exact Lean checking with an empty axiom inventory. Two observations supply polymorphic payloads returning 37 and 53 and check the respective values extracted from the resulting boxes. This prevents a constant replacement from satisfying both observations. The reference never enters the live synthesis environment.

Ordinary, named-`where`, and actual-False Djinn commands all terminate with a contextual source-admission error. The False command is also an error, not an accepted negative control. No search result or selected-type reconstruction acceptance is claimed from these runs.

Source inspection identifies the immediate restriction: nominal declaration telescopes are accepted only when their parameters and result are Type 0. The box parameter is Type 1. The source projector also has a separate `ContextUnsupportedSelectedPolytype` refusal, but these public commands do not reach that later boundary. A single generic error message must not be treated as evidence that both boundaries have been exercised.

## Implementation direction and acceptance gates

The working implementation now carries an explicit declaration universe signature and its selected level vector. It normalizes declaration-local parameter names independently of caller levels, checks selection arity and scope, retains argument/result sorts, and distinguishes nonzero selections in private nominal and constructor identities. Those changes are under validation and are not part of this diagnostic publication.

First require the emitted Lean serializer to compile and a monomorphic higher-universe box to synthesize and replay. Then rerun the original polymorphic box query without changing its signature or observations. If admission succeeds but reconstruction refuses its selected forall, preserve the actual source binder evidence through that application rather than inferring universe metadata from erased types. Higher-universe classes and generic global-provider discovery retain their own subsequent gates.

The [current priorities](2026-09-14-synthesis-next-priorities.md) now advance from the completed bounded comparison to this source prerequisite. No Church behavior ledger counts change.

## Retained evidence

The [diagnostic archive](../../test-church/receipts/selected-polytype-frontier-2026-09-14.zip) and [member manifest](../../test-church/receipts/selected-polytype-frontier-2026-09-14.json) contain both private attempts, their changed fixture snapshots, controllers, logs, the three public commands and the exact Lean reference replay. Their receipts record unchanged captured sources and runtimes at completion. Full unchanged baseline sources and executable binaries are excluded; their identities remain in the receipts. The private baseline is Djex `31ffa3c87d2241212d2b85e7e4f9168fdbf7ab66`, whose relevant Djinn/shared/frontend sources match the current published revision. The native producing sources are retained in the separate contextual binder-universe acceptance archive.

Archive SHA-256: `1cb417593eb3ad1ca5e3fe9f40683040ddc7872b4ddb221383f8540e23b9890f`; 304,002 bytes; 33 members.
