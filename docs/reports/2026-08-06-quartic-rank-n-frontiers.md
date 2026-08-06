# Quartic rank-N frontiers in Leant

Date: 2026-08-06

## Outcome

Leant now consumes Djinn's quartic positive-forall plan family. The Djex
submodule advances to `a084a8c5`, where deterministic quadruple-opaque and
quadruple-open plans extend structural rank-N coverage from seven through nine
independent quantified sites.

No bridge-specific production rule was required. Leant's existing fragment,
engine runner, shared-expression renderer, and Lean verification boundary
already preserve the quantified occurrences and accept the new checked Djinn
candidates. The integration work pins that compatibility directly rather than
assuming a submodule bump is sufficient evidence.

## Exact witness

The regression uses four distinct schemes with five leading type binders and
four polymorphic identities. Its result needs the four schemes transported as
exact opaque values while all four identities open structurally.

Five binders are deliberate. Djinn's separate hypothesis-instantiation family
accepts at most four, so it cannot synthesize this query by specializing a
scheme and accidentally hide an occurrence-planning regression. The successful
candidate therefore witnesses the formerly missing flat four-open/four-opaque
selection.

The pure Leant boundary test constructs that fragment directly, invokes
standalone Djinn, and requires a rendered nested-product candidate. The live
[`synth-quartic-rankn`](../../test/synth-quartic-rankn.txt) transcript sends the
same logical shape through the Lean 4.31 backend under both `djinn` and `both`.
Lean accepts the displayed term against the original dependent-function type;
the transcript therefore checks parsing, fragment conversion, search,
rendering, and final elaboration together.

## Engine boundary

This milestone widens Djinn's occurrence planner. It does not claim that
Exference's ranked heuristic independently reaches the same eight-component
query. In combined mode the verified Djinn candidate survives while Leant
retains Exference's step/queue truncation note. That is the intended `both`
contract: a bounded miss from one engine cannot discard a checked candidate
from the other or become a negative verdict.

The historical result-order prefix is unchanged. Quadruple plans follow triple
plans, and Leant still displays only terms which its backend elaborates. The
quartic family is exhaustive through nine independent sites; a flat ten-site
five-open/five-opaque choice remains outside the bound and must stay
inconclusive.

## Verification

- Djex `djinn-tests` and `djex-tests` pass at the pinned revision.
- Leant's focused eight-site boundary regression passes.
- The live transcript succeeds under standalone Djinn and combined mode, with
  every displayed candidate accepted by Lean 4.31.

The plan family grows as `O(n^4)`, so the new layer trades bounded runtime for a
strict completeness gain without claiming general impredicative inference.
