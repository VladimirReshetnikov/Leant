# Guarded conditional Length ranking

Date: 2026-08-15

## Outcome

Leant's one current applicable-domain ranking policy now inherits Djex's exact
guarded `LengthIf` coverage. Fully supported expression conditionals can
establish finite scalar or nominal binary-product receipts during the pure
MRU/domain/origin prefix, before any Z3 process is opened. The Djex production
implementation is `eb7ec48aac85dd257d9046a847e47dbce91c264d`; Leant's tandem
characterization is `a93e7f2ca3e501d4be6158ef817261632644cba7`.

This is a revision of one experimental current contract, not a new policy
version or compatibility layer. Leant and Djex promise no stability or
backward compatibility at this stage and have no userbase requiring historical
choices to remain accepted. The short builder, assessment, error, receipt, and
renderer families remain the only public applicable-domain surface. The
startup and command-local JSON documents remain their single current,
versionless schemas; no `version`, strategy selector, migration decoder, or
alias was added.

## Exact guarded coverage

Inside an otherwise ignored relational atom, the recursive expression grammar
now includes:

```text
if condition then whenTrue else whenFalse
```

Admission is all-or-nothing. Every leaf in both the positive and negative
expansion of `condition`, and every descendant in both selected expressions,
must be supported. This check includes an arm made unreachable by a constant
condition. A quotient, modulo, result reference, out-of-range input, retained
zero scale, or any other unsupported required descendant rejects the complete
fallback atom. Djex neither drops an unsupported arm nor guesses a guard.

An admitted conditional contributes this ordered alternative stream:

```text
positive DNF(condition) x recursive cases(whenTrue)
negative DNF(condition) x recursive cases(whenFalse)
```

The true arm precedes the false arm. Within one arm, condition alternatives
are outermost and selected-expression alternatives are innermost. Condition
coverage precedes selected-arm guards, those guards precede enclosing
minimum/maximum/monus selectors, and the final relation rules come last.
Negative equality retains its exact two strict alternatives.

A contradictory conditional guard keeps its selected value until the
enclosing relation forms coverage. It therefore participates in the complete
raw Cartesian product and consumes generated-branch work before contradiction
collapse. This preserves the established order: raw branch admission, original
literal-set cleanup and re-expansion, per-branch rule admission, closure
admission, contradiction removal, complete input coverage, box antichain,
visit/assignment limits, original-problem replay, receipt construction, and
exact query association.

The derived guards and boxes are coverage machinery only. Every unique
assignment is still replayed in global lexicographic order against the exact
original checked precondition and postcondition. Neither a derived guard, an
inferred maximum, nor solver status becomes behavioral authority.

## Canonical behavior

The one-input contract

```text
(if x <= 2 then x else 5) <= 3
```

has two raw alternatives. A generated-branch cap of one observes two. Its
false branch later collapses, leaving the provider-independent box `[[2]]`
with one box, three visits, three unique assignments, and three applicable
assignments.

For

```text
(if x = 0 then 1 else x) <= 2
```

the complemented equality supplies two strict alternatives. A cap of two
therefore observes three, while the final receipt is again `[[2]]` with
3/3/3 visit, unique, and applicable counts.

The nested fixture

```text
y <= 2
(if x <= 1 then max(x,y) else x monus y) <= 2
```

has four raw alternatives. A cap of three observes four; its first expanded
branch has four rules, and a closure cap of three observes four inspections.
The exact result is `[[4,2]]` with one box, 15 visits, 15 unique assignments,
and 12 applicable assignments. An independent enumeration over the wider
`[0..5] x [0..3]` rectangle confirms that every satisfying assignment in that
range is covered. Replacing the false arm with `x modulo 2` makes the complete
atom conservatively inapplicable.

Scalar and product validators retain these semantics behind nominally distinct
receipts. Their query wrappers associate the receipt last without changing the
original query fingerprint, check bytes, symbols, or value request.

## Leant startup and presentation

Leant's current versionless startup root remains the exact ten-member form
selected by `rankingDomain`. Its `applicableDomainValidation` member still has
exactly seven numeric limits and no `strategy`. The separate command-local
root remains exactly `{format, rankingDomain, contract}`. `LengthIf` was already
part of both nested expression grammars, so the decoders and passive contracts
needed no new field or routing rule.

The tandem test decodes the same guarded contract through complete scalar and
binary-product startup documents. It asserts their nominal selections and
checked preconditions, establishes the matching provider-independent `[[2]]`
receipts with 1/3/3/3 accounting, and pins the scalar and product presentation
notes. The configured executable is deliberately absent; both the executable
path and its event path remain absent, demonstrating that establishment is
pure and deferred opening is preserved.

The current ordering remains:

```text
four-entry newest-first MRU replay
  -> guarded applicable-domain traversal
  -> all-zero origin probe
  -> live query and query-first replay
  -> post-unsat explicit input-box traversal
```

A guarded establishment or counterexample skips the later stages. An
inapplicable result or bounded admission miss continues normally. Stable
ranking, no-prune behavior, counterexample simplification, MRU promotion,
nominal scalar/product separation, and atomic original-order fallback are
unchanged.

## Inherited descriptor ownership

The final vendored Djex snapshot also contains the native process-ownership
hardening in `1bbf562436b5470ab9a9b501908c813cc07fe436` and
`fbdc63a3e1af9fe242c0721c518c73e6bb6e994b`. It is inherited by Leant's fixed
descriptor-bound execve-check policy without changing the Leant configuration
grammar or any behavioral receipt.

A resource-producing deadline worker remains masked through publication of one
terminal completion value as its final effect. Cancellation, deadline loss, or
a controller exception joins through that same completion and rolls back any
acquired value. All three native descriptor strategies then use one shared
masked handoff: raw `DescriptorCreated` cleanup protects a restored
post-acquisition checkpoint; the consumer allocates the opaque process while
masked; and restored initialization begins only after that process is the sole
cleanup owner. The child exec-status `Handle` is closed in a masked finalizer
on normal EOF, child-reported exec failure, synchronous read failure, deadline
cancellation, and asynchronous interruption.

These rules prevent leaked process resources. They do not attest an
interpreter, loader, library, solver semantics, solver status, or candidate
behavior, and they mint no evidence.

## Identity and compatibility boundary

Djex reset the package-private scalar and product applicable-domain receipt
discriminators because guarded coverage changes algorithm semantics. They have
no public projection or persistence/migration promise. Leant consumes only the
opaque current receipt and its six public projections. No public JSON schema,
query bytes, protocol, or behavioral-problem identity changed.

That distinction is deliberate but not a stability guarantee. The projects
remain free to revise public and private contracts before a stable release.
The versionless JSON roots describe what the current decoder accepts, not a
promise that every future decoder will accept the same shapes.

## Frozen validation

The final vendored documentation snapshot is
`a9150c77623767f187d64af5d3cd75ec1194f67b`; Leant pins it in
`32059c2c39f42d30a62a25b58369669e4ae64c58`. Leant's guarded tandem test landed
earlier in `a93e7f2ca3e501d4be6158ef817261632644cba7`.

At that frozen source checkpoint:

- `test-unit/Spec.hs` has 17,724 lines and 392 literal `testCase` tokens;
- 391 Leant suite cases execute;
- the focused current applicable-domain group passes 8/8;
- the complete Leant unit suite passes 391/391;
- Djex passes all 16 suites and 1,807 tests; and
- the Djex Length suite passes 370/370.

Strict warning-as-error builds, the complete Cabal test matrices, `cabal check`,
and diff checks were green at the implementation and pin checkpoints.
The final documentation commit and rendered PDF measurements are intentionally
recorded only after the source-document merge freezes their exact links.

## Documentation boundary

Current Leant behavior is specified by the
[Length ranking reference](../length-ranking.md) and
[`synth` internals map](../synth-internals.md). Djex owns the exact guarded
algorithm in its
[guarded conditional report](../../lib/Djex/docs/reports/2026-08-15-guarded-conditional-length-applicable-domain.md)
and the inherited process transition in its
[descriptor ownership report](../../lib/Djex/docs/reports/2026-08-15-descriptor-spawn-resource-ownership.md).
The numbered and earlier recursive reports remain historical engineering
records, not current schemas or compatibility commitments.
