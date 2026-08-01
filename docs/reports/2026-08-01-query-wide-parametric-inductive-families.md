# Query-wide proper-type inductive families

**Date:** 2026-08-01

**Scope:** Leant's non-recursive Lean-to-Djex bridge for rank-N and
impredicative synthesis

## Outcome

Leant can now give every compatible proper-type application of one
non-recursive Lean inductive the same engine-side family identity without
losing its constructor structure. This closes the gap between two previously
separate capabilities:

- retained nominal applications could transport `Wrap a` to `Wrap poly`, but
  deliberately exposed no constructors; and
- expanded inductive occurrences exposed constructors and cases, but separate
  instantiations such as `Option a` and `Option poly` did not share one
  parameterized family.

The new projection supports both at once. In provider-free engine requests,
Djinn and Exference can synthesize:

```lean
((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
((∀ e a : Type 1, Except e a) →
  Except (∀ b : Type, b → b) (∀ c : Type, c → c))
```

as `fun x => x _` and `fun x => x _ _`, while ordinary `Option`/`Except`
constructor introduction and case elimination remain available.

## Fragment boundary

The Lean serializer emits:

```text
FParamInd exactHead displayKey parameters constructors
```

only for a qualifying non-recursive, non-indexed, non-mutual inductive with a
complete explicit, non-dependent constructor inventory. Every application
argument must be a **proper type**: after inference and weak-head reduction,
its type must be a universe. This admits ordinary type parameters and supplied
polytypes. It does not confuse term arguments, proofs, or dependent parameters
with Djex datatype parameters.

Term/dependent parameter vectors retain the established occurrence-local
`FInd` representation when that representation is otherwise admissible. An
unsupported application remains opaque. The distinction is semantic rather
than spelling-based and is made by Lean after elaboration.

`FParamRec` records the corresponding exact head and proper-type vector for a
recursive occurrence, but this report does not add query-wide recursive-family
sharing or broaden recursive elimination; see
[Deferred recursive work](#deferred-recursive-work).

## Query-wide planning

The engine pre-scans the complete query before translating any occurrence. The
input comprises:

- caller premises,
- the engine goal, and
- every Exference provider that survived depth admission.

Uses are grouped by exact Lean head. A structural occurrence contributes its
parameter vector and complete specialized constructor inventory. A retained
opaque use of the same nominal head contributes its arity but no schema.

For each head, planning applies these rules:

1. All uses must have one arity. Inconsistent arities are rejected rather than
   conflated.
2. A structural template candidate must come from an occurrence whose
   parameter fragments are pairwise distinct.
3. Whole parameter fragments are replaced with private formals before
   structural descent. Substitution is alpha-aware and capture-avoiding, which
   matters for structured parameters and constructor-local `forall`s.
4. The generic constructor fields must be closed over only those formals and
   their own local binders. Fixed opaque atoms are closed separately during
   lowering.
5. Specializing the candidate template with every occurrence's parameter
   vector must reproduce that occurrence's constructor schema.
6. If several candidates pass, they must be equivalent. Otherwise the schema
   is ambiguous.

Nested exact inductive nodes are compared by head and parameters. Their display
keys and constructor inventories are metadata owned by their independent
query-wide plans; including that metadata in outer-family identity would make
semantically equal parameters look distinct and would let an inner conflict
poison an otherwise valid outer declaration.

The resulting decision matrix is:

| Query-wide evidence for one head | Representation | Constructor search | Djinn negative evidence |
| --- | --- | --- | --- |
| Unique compatible schema | Shared parameterized data | Yes | Eligible if every other projection boundary is complete |
| Repeated parameters, resolved by another validating generic occurrence | Shared parameterized data | Yes | Eligible under the same completeness rule |
| Repeated/ambiguous parameters with no validating template | Shared abstract family | No | Disabled |
| Incompatible constructor schemas | Shared abstract family | No | Disabled |
| Structural occurrence plus opaque nominal use | Shared abstract family | No | Disabled |
| Nominal uses only | Shared abstract family | No | Governed by the nominal atom's ordinary unsafe-evidence rule |
| Inconsistent arities | Translation error/refusal | No | No verdict |
| Term/dependent parameters | Legacy occurrence-local path | As supported by that path | Governed by its existing completeness rules |

The abstract fallback is query-wide too. It preserves exact-head identity, so
positive rank-N transport may still work, but it never exposes a constructor
inventory that could be wrong.

## Lowering and fixed fields

A structural plan produces one Djex `DataTypeDeclaration` with one parameter
per Lean family parameter. All occurrences lower to applications of that same
private type constructor. Constructor names are private inside Djex and map
back to their exact Lean spellings during rendering.

A constructor field can contain a concrete type that is not a family
parameter. For example:

```lean
axiom Demo.Secret : Type
inductive Demo.Guard (a : Type 1) : Type 1 where
  | mk : Demo.Secret → a → Demo.Guard a
```

Treating `Demo.Secret` as a fresh flexible datatype variable would leave the
shared declaration ill-scoped and could identify it with unrelated types. The
translator instead creates one private rigid proper-type declaration and maps
it back to the parenthesized exact Lean type if it appears in a visible type
argument. The varying `a` remains the sole `Demo.Guard` parameter.

Rigid-atom collection follows the fields actually consumed by a structural
plan. It does not descend into a nested `FParamInd` constructor inventory,
because that inventory is translated only if the nested family's own plan is
structural.

Exference's existing one-layer recursive representation needs the same closure
invariant even though query-wide recursive-family sharing is deferred. An
order-independent query-wide pre-scan collects fixed opaque constructor fields
for every eligible structural recursive family before any fragment is lowered.
It adds those fields to the private rigid proper-type seed, then subtracts all
recursive self keys from the combined seed. Consequently a recursive self
reference resolves through `tsInds` after the datatype knot is installed,
rather than becoming an unrelated rigid atom merely because it appeared before
the recursive result during traversal. This prevents a zero-parameter provider
result such as `Std.Format` from producing an ill-scoped Djex declaration
through its fixed `String` field.

## Rendering at an occurrence

One shared declaration carries generic constructor fields, but Lean candidate
fitting happens at a particular result or scrutinee occurrence. Constructor
metadata therefore records both the exact family head and the private generic
formals. When fitting an introduction or match, the renderer:

1. checks that the occurrence has the same exact head;
2. prefers the complete fields serialized on that actual occurrence; and
3. uses capture-safe generic specialization only as a defensive fallback.

This preserves rank-N field domains for constructor arguments and pattern
binders even when the generic template came from a premise or provider with
different local binder names.

## Engine behavior

Both engines consume the same shared datatype declarations.

- **Djinn** retains structural constructor/case plans and can also use Djex's
  guarded nominal projection to instantiate a quantified family value at a
  query-supplied polytype. The direct Lean rendering is `fun x => x _` (or one
  `_` per family parameter).
- **Exference** can perform the same family transport and keeps its normal
  ranked constructor/case search. In standalone mode, a structurally accepted
  goal first runs without live providers and its candidates are Lean-verified;
  providers are discovered and searched only after no baseline variant
  verifies. It never emits negative evidence.
- **Both** mode keeps the established isolation: Djinn candidates first,
  Exference-only candidates after, and negative evidence only from Djinn when
  its projection was complete.

Every rendered candidate is re-elaborated by Lean against the original goal.
The engine is useful for discovery, not part of the trusted kernel boundary.

## Negative-evidence contract

Leant tracks two independent completeness facts for Djinn:

- every exact family plan exposed all structure needed for its chosen
  representation; and
- the goal and caller premises contain no depth truncation or unsafe opaque
  structure.

The fitted Lean goal is checked as well when it differs from the engine goal.
An ambiguous/incompatible structural family produces `SynthNoTerm` on search
exhaustion. Other unsafe fragment structure produces a non-proof
`SynthRefuted False` outcome, which the REPL presents as "no term found within
bounds", not as proof of uninhabitation.

Including caller premises is essential. A premise such as `Fin 1 → R` can
inhabit `R` using concrete Lean structure even if the abstract logical
projection cannot construct `Fin 1`; ignoring that hidden premise structure
would make a negative verdict unsound.

## Validation coverage

The focused Haskell tests cover:

- direct `Option`-like transport in Djinn and Exference;
- constructor introduction, case elimination, and rank-N field fitting;
- fixed opaque fields, rigid visible-type restoration, and an order-sensitive
  zero-parameter recursive regression whose fixed-field argument is lowered
  before its recursive result;
- provider- and caller-premise templates discovered below outer connectives;
- repeated parameter ambiguity and recovery from a later generic occurrence;
- schema disagreement and structural/nominal collision fallbacks;
- exact-head separation despite display-key collisions;
- alpha-equivalent fields, capture avoidance, and nested-family metadata
  isolation; and
- negative-evidence honesty for abstract families and unsafe caller premises.

The end-to-end
[rank-N transcript](../../test/synth-parametric-rankn.txt) covers real `Option`
under standalone Exference as well as Djinn. Exference's provider-free baseline
is Lean-verified before inventory discovery, so the eighty root-local providers
can no longer crowd this direct transport out of the bounded frontier. The
transcript also covers two-parameter `Demo.Phantom2` and fixed-field
`Demo.Guard` transport under both engines. Atomic `Demo.Secret` and structural
`Unit → Demo.Secret` controls demonstrate, respectively, the direct provider
path and provider fallback after a structural baseline miss. A
term-parameterized `Demo.Tag` control confirms that the legacy occurrence-local
path still constructs its value. See the focused
[provider-isolation report](2026-08-01-provider-isolated-exference-baseline.md)
for the dispatch, shared-deadline, and failed-variant filtering rules.

## Deferred recursive work

Recursive exact-family sharing is a separate design problem, not an omitted
case of the finite-data algorithm. Current behavior remains:

- Djinn treats a recursive occurrence as opaque and receives its constructors
  as sound introduction premises.
- Exference may receive a complete nominal recursive datatype and inspect one
  constructor layer; recursive fields remain ordinary branch-local values.
- When Exference's structural recursive projection is enabled, a query-wide
  pre-scan closes the fixed fields of eligible recursive families before any
  fragment is lowered while excluding recursive self keys from the rigid seed,
  preserving resolution through `tsInds`.

Sharing `FParamRec` query-wide will need a validated recursive knot, a schema
policy for differently instantiated occurrences, and occurrence-specialized
renderer fields for the shared recursive constructor map. Until then, `List`
retains the established bounded behavior while `Option`, `Except`, and
qualifying user-defined non-recursive families use the new exact-head plan.
