# Quartic rank-N frontiers in Leant

Date: 2026-08-06

> **Follow-up.** The
> [quintic successor](2026-08-06-quintic-rank-n-frontiers.md) closes the
> ten-site five-open/five-opaque gap, adds the eleven-site dual, and gives
> Leant a genuinely non-vacuous live serializer regression.

## Outcome

Leant consumes Djinn's quartic positive-forall plan family, introduced in
Djex at `a084a8c5`: deterministic quadruple-opaque and quadruple-open plans
extend structural rank-N coverage from seven through nine independent
quantified sites. Djex `f3dd2495` also lets Exference forward complete scoped
arrow schemes through a structurally constructed nested boxed product. The
current Leant submodule advances once more to `c0c1a461`, which bounds that
shortcut's recursive derivation histories without removing deep product
reuse.

Those are separate claims. Djex's core regression is the evidence for the
genuine four-open/four-opaque quantified frontier. Leant's historically named
`synth-quartic-rankn` regression is an end-to-end serializer and engine-boundary
test, but its actual fragment does not contain four opaque five-binder
schemes.

## Exact live shape

The Lean source starts with four outer quantified result types `Q`, `R`, `Z`,
and `M`. Its body presents four vacuous schemes with five leading type binders,
four result components with the same surface syntax, and four polymorphic
identity leaves. The outer four binders remain `FAll`. Since none of the five
inner bound names occurs in its codomain, however, the serializer lowers each
inner surface scheme

```text
forall A B C D E : Type, Q
```

to five ordinary arrows from one shared opaque `Type` atom:

```text
Type -> Type -> Type -> Type -> Type -> Q
```

The same lowering applies to the corresponding result component. More
precisely, after the outer `FAll s0` through `FAll s3`, the fragment has four
such arrow-chain inputs and a right-nested `FProd` whose first four leaves are
the matching arrow chains. These nodes are `FArr`, not opaque `FAll`, and
therefore do not exercise Djinn's greater-than-four
hypothesis-instantiation guard. Among the eight result leaves, only the final
four identities retain quantified fragment form, each equivalent to
`forall E. E -> E`.

The focused pure Leant boundary test now constructs this exact fragment rather
than a superficially similar model which represented every vacuous binder with
`FAll`. It requires Djinn, Exference, and combined mode to include the direct
rendered candidate:

```text
fun _ _ _ _ f g h f1 => ⟨f, ⟨g, ⟨h, ⟨f1, ⟨fun _ x => x, ⟨fun _ y => y, ⟨fun _ z => z, fun _ w => w⟩⟩⟩⟩⟩⟩⟩
```

The live
[`synth-quartic-rankn`](../../test/synth-quartic-rankn.txt) transcript sends
the same shape through the Lean 4.31 backend. Lean accepts the displayed term
against the original dependent-function type, covering parsing, fragment
conversion, search, rendering, and final elaboration together.

## Exference boundary

Djex `f3dd2495` adds two cooperating Exference paths. One reconstructs the
complete arrow scheme stored behind a split scoped binding and offers exact
whole-value forwarding before eta expansion. The other materializes an entire
known nonempty boxed-tuple tree at once and schedules only its leaves, while
retaining the older one-layer tuple branch for searches which reuse an
existing inner product.

Djex `c0c1a461`, the revision now pinned by Leant, adds structural tuple
provenance to that choice. An independently scheduled structural route may
take the eager whole-tree shortcut once, but fields created by its shallow
sibling remain on the shallow lane through arrows, nested forall opening,
partial applications, and pattern-match continuations. This prevents the same
saturated tuple from being rediscovered through every recursive subtree while
preserving scoped and environment product reuse at arbitrary depth.

With those paths, standalone Exference reaches the direct candidate under the
unchanged 4096-step and 1024-entry queue bounds. The independent Djex
expression checker admits it at search step 30. This is a positive bounded
result; it is not an assertion that the rest of the ranked search finishes.

The live transcript makes that distinction explicit. After displaying the
verified candidate, standalone Exference continues searching and eventually
reports:

```text
note: search truncated: step limit reached, queue limit pruned 36475
```

Combined mode retains the same Exference tail note alongside its merged
candidates. The 36,475 prunes describe work discarded from the unfinished
tail; they do not weaken the already checker-admitted and Lean-verified direct
candidate.

Leant independently protects the candidate frontier: it stable-deduplicates
rendered Exference groups before applying the internal 60-candidate collection
window. The first rendered spelling remains authoritative, but equivalent
backend histories cannot crowd later distinct terms out of the bound. This
changed a recursive rank-N transcript by exposing another Lean-verified
candidate; the focused quartic transcript and its step/prune observations
remain unchanged.

## Remaining frontier

Djinn's historical result-order prefix is unchanged: quadruple plans follow
triple plans. The true quartic family remains exhaustive through nine
independent quantified sites; a flat ten-site five-open/five-opaque choice is
outside the bound and must stay inconclusive. The Leant live regression should
not be cited as direct evidence for that plan boundary because its vacuous Pis
serialize as ordinary arrows.

## Verification

- Djex `c0c1a461` passes all 489 Exference tests, all 27 private engine tests,
  and all 82 Djex facade tests.
- Leant's focused serializer-parity boundary regression passes under Djinn,
  Exference, and combined mode at 4096 steps and queue size 1024.
- The live transcript succeeds in all three modes, with every displayed
  candidate accepted by Lean 4.31; the Exference and combined runs retain the
  honest bounded-tail note with 36,475 queue prunes.
- All 177 Leant synthesis-boundary tests pass at the current submodule pin.

The quartic Djinn plan family grows as `O(n^4)`, so it trades bounded runtime
for a strict completeness gain without claiming general impredicative
inference. Exference's result is separately a successful bounded heuristic
search, not a completeness claim.
