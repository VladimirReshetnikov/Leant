# Quintic rank-N frontiers in Leant

> **Follow-up.** The
> [five-binder integration](2026-08-09-five-binder-instantiation.md) raises the
> separate instantiation cap from four to five. The live `Wide` sentinel now
> has six adjacent binders, preserving the occurrence-frontier witness recorded
> below without allowing instantiation to rescue it.

Date: 2026-08-06

## Outcome

Djex `d728719f` extends Djinn's polarized positive-forall plan family with
quintuple-opaque and quintuple-open tails. The historical fully open, fully
opaque, singleton, pairwise, triple, and quadruple plans retain their order.
Each new orientation alternates selections from both source edges and compiles
at most 512 views. This includes all 252 five-site selections among ten sites
and all 462 among eleven, so every open/opaque choice is covered through eleven
independent quantified occurrences. A flat twelve-site proof needing exactly
six open and six opaque occurrences remains outside the bounded family.

Leant `378f866` advances the Djex submodule and fixes the adapter needed to
make that coverage real for Lean source. Leant `80f123a` adds an end-to-end
transcript with non-vacuous five-binder schemes. Its two direct Djinn
candidates survive fragment translation, bounded planning, rendering, and
final elaboration by Lean 4.31 without a search-truncation note.

## Why adjacent `FAll` nodes must coalesce

The Lean serializer retains one `FAll` node per dependent type binder. It must
do so because the fragment records whether every binder was explicit and the
renderer later uses those slots to place Lean lambdas and type arguments. A
written scheme such as

```text
forall A B C D E : Type, A × B × C × D × E
```

therefore reaches the Haskell fragment as five adjacent `FAll` nodes. Before
this integration, Leant projected each node independently to
`ForallType [v] [] body`. Djinn consequently saw five nested positive-forall
sites where its native Haskell parser saw one `ForallType [a,b,c,d,e]`. A live
query with five such schemes and five identities did not exercise the claimed
ten-site frontier; it presented a much larger nested occurrence tree instead.

The adapter now collects each uninterrupted `FAll` spine and emits one
`ForallType` with the complete binder list. Collection stops at every other
fragment node, including `FInst`, so it cannot move a type binder across erased
instance evidence or change lexical scope. The original fragment is unchanged
and remains the rendering authority, preserving every explicitness slot. This
is a representation-parity correction, not a new inference rule or an
unchecked impredicative coercion.

## Exact live shapes

The live
[`synth-quintic-rankn`](../../test/synth-quintic-rankn.txt) transcript defines:

```text
abbrev QuinticRankN.Wide :=
  forall A B C D E : Type, A × B × C × D × E
```

Write `W` for that complete scheme and `I` for `forall A : Type, A -> A`.
After adjacent-spine coalescing, each `W` and each `I` is one independently
reachable positive-forall site.

The first goal has the projected shape:

```text
W -> W × W × W × W × I × I × I × I × I × W
```

The five `W` results at positions 1--4 and 10 must remain exactly opaque. If
one opens, constructing an arbitrary five-component product would require
values of five unrelated types. The five identity results at positions 5--9
must instead open structurally because no exact identity hypothesis is in
scope. Five-binder hypothesis instantiation cannot rescue an opened `W`:
Djinn's separate context-free instantiation rule still admits at most four
leading binders. Thus the direct proof specifically needs a non-prefix
five-opaque/five-open selection:

```text
fun x => ⟨x, ⟨x, ⟨x, ⟨x, ⟨fun _ y => y, ⟨fun _ z => z, ⟨fun _ w => w, ⟨fun _ x1 => x1, ⟨fun _ x2 => x2, x⟩⟩⟩⟩⟩⟩⟩⟩⟩
```

The second goal has the dual eleven-site shape:

```text
W -> I × I × I × I × W × W × W × W × W × W × I
```

Here the identities at positions 1--4 and 11 must open, while six `W` siblings
remain opaque. This requires the separately scheduled quintuple-open category,
not the ten-site quintuple-opaque plan:

```text
fun x => ⟨fun _ y => y, ⟨fun _ z => z, ⟨fun _ w => w, ⟨fun _ x1 => x1, ⟨x, ⟨x, ⟨x, ⟨x, ⟨x, ⟨x, fun _ x2 => x2⟩⟩⟩⟩⟩⟩⟩⟩⟩⟩
```

Live-library synthesis is disabled for the transcript, so both results measure
the provider-free Djinn boundary. Lean accepts each rendered candidate against
its original goal, and neither query reports candidate, step, or queue
truncation.

## Bounds and remaining frontier

The fifth-order family is bounded independently in each orientation. At ten
sites, `C(10,5) = 252`; at eleven, `C(11,5) = 462`. Both complete layers fit
below the 512-view cap. On larger inputs the two quintic categories add at most
1,024 compiled views in total, rather than continuing to grow as `O(n^5)`.
Edge-balanced enumeration prevents the retained prefix from considering only
early source sites.

The cap does not make arbitrary rank-N inference complete. In particular:

- a twelve-site six-open/six-opaque choice remains outside the occurrence-plan
  family;
- hypothesis-side and loaded-scheme instantiation still stop at four leading
  binders;
- Exference remains a separately bounded heuristic engine; and
- every miss at one of these incomplete boundaries remains operationally
  inconclusive rather than a proof of non-inhabitation.

Every positive candidate still crosses Djex's independent checker and Lean's
elaborator before Leant displays it.

## Verification

- The final combined synthesis-boundary run passes all 179 cases, including
  adjacent-spine coalescing and both quintic orientations.
- The two-query `synth-quintic-rankn` golden was regenerated and replayed with
  the pinned Lean 4.31 backend; both direct terms were accepted and neither run
  was truncated.
- The neighboring `synth-quartic-rankn` golden was replayed twice. Its checked
  terms and truncation reasons are unchanged; the stable queue-prune count is
  now recorded as 36,475.
