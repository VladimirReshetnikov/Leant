# Structured contextual exact provider assignments

Date: 2026-08-09

## Outcome

Leant now preserves a closed nominal class context inside the exact type
argument established by one active Lean instance head. This closes the gap for
provider assignments such as

```lean
abbrev Choice := {a : Type} → [Inhabited a] → a → a

class Pick (a : Type 1) : Prop where
  witness : True

instance : Pick Choice := ⟨True.intro⟩
axiom chosen {a : Type 1} [Pick a] : Token
```

The active head can now contribute `Choice` as the exact named argument to
`chosen` in standalone Djinn, standalone Exference, and combined mode. Djex
sees and checks the contextual scheme rather than a context-erased
approximation, and Lean still elaborates and kernel-checks every rendered
candidate.

## Structured assignment-local evidence

The generated serializer has a dedicated exact-assignment mode. After reducing
an instance binder, it accepts only a genuine nominal Lean class application
whose ordered arguments are proper types. It emits `FExactContext`
with the exact class name, bounded kind/fragment arguments, and contextual
body. No pretty-printed binder syntax becomes executable metadata.

Leant translates each exact class head to a collision-free private Djex class,
retains its constraints in the corresponding `ForallType`, and maps the
private name back to the same fully qualified Lean class during rendering.
Constraint arguments and the body participate in closure, equivalence,
specialization, fitting, and forall-metadata traversal, so the rendered named
argument remains paired with the scheme Djex checked.

This representation is local to one exact provider-assignment vector.
Ordinary goal serialization still uses `FInst` only as a render-time wildcard,
and provider-scheme serialization still erases instance evidence for Lean to
reconstruct. Neither path gains general contextual search, and no dictionary
term crosses the bridge.

## Fail-closed boundary

The extension is deliberately narrower than general constrained
impredicativity. A complete exact vector is rejected when it contains:

- legacy raw `FInst` or depth truncation (`FDepth`);
- malformed or over-bound contextual wire data;
- metavariables, free variables, loose binders, or an unresolved class head;
- a contextual result type that depends on the dictionary term;
- term-indexed class arguments; or
- any unsupported class-argument kind or fragment shape.

The existing provider identity, arity, positional-kind, vector, and search
bounds remain in force. Structured context support changes neither ordinary
goal/provider schemes nor negative-evidence policy.

## Regression evidence

Pure regressions cover structured wire parsing, legacy `FInst` rejection,
context-preserving translation and rendering, and exact provider selection in
Djinn, Exference, and combined mode. The live
[`synth-provider-contextual-assignment`](../../test/synth-provider-contextual-assignment.txt)
transcript makes the contextual `Choice` the only active assignment and
requires every engine mode to produce a Lean-verified specialization. Its
`DependentContext` control also gives every mode an active dictionary-dependent
choice and requires that no proposed spelling survive Lean verification.
