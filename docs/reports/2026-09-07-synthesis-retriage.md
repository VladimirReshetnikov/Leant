# Synthesis re-triage: Leant integration and remaining capabilities

This 2026-09-07 update preserves the active goal to implement priorities 1–4
from the [accepted roadmap](../../lib/Djex/docs/reports/2026-09-06-synthesis-next-priorities.md).
The shared implementation and acceptance checklist are maintained in Djex's
`docs/reports/2026-09-07-synthesis-priorities-1-4.md`; its updated execution
recommendation is `docs/reports/2026-09-07-synthesis-retriage.md`. These new
documents are not yet part of Leant's pinned Djex revision.

## Current boundary

At Leant `769369d4f85f07341bc8d444234a18e330d0edbf`, the Djex submodule is
`7ea70a8e594762872d6511ecd0891294bd053022`. Standalone Djex has since reached
`0a79d2311d966f7689c52a33c211f49f3a15bbea`, implementing Haskell source-graph
rendering and bounded behavioral elaboration retries. Its recorded 100 facade,
466 shared-synthesis, and 98 CLI tests are Djex checkpoint evidence. They do
not establish acceptance in this Leant checkout.

The positive GHC repair fixture exercises a graph-rendered impredicative let;
successful repair through the complete live public query path is still open.
The inspected live `reverse` failure had no source graph and therefore could
not authorize an annotation retry. Keep those two failure classes separate.

## Delivery order

1. **Close priority 1 acceptance, then integrate and validate Djex in Leant.**
   Require a live graph-present repair, exact checked/displayed text across
   selection modes, missing-authority and scope rejection controls, and the
   original resource bounds. Advancing the submodule alone is not integration
   acceptance.
2. **Implement priority 2's one-layer cases.** Target ordinary `null`,
   `headOr`, `tailOr`, and shallow tree inspection. Preserve exact family and
   constructor identities, opaque recursive fields, and independent Lean
   replay. `tailOr` needs compatible input and result views.
3. **Deliver priority 4's bounded Lean simplification.** After decision checks
   for the assertion and its negation, attempt bounded simplification. Require
   a complete kernel proof, retain axiom inventories and the command deadline,
   and keep false and inconclusive outcomes distinct.
4. **Deliver priority 2's supplied folds/recursors.** Use generic recursion
   structure to target operations such as `map`, `append`, and `length`, with
   checked source evidence and termination guarantees. Add behavioral corpus
   cases alongside this work.
5. **Implement priority 3's contextual evidence.** Start with forwarding and
   dictionary-independent bodies under lexical givens, then methods,
   conditional providers, and superclasses. Retain identities and scoped
   obligations throughout Djinn's provider projection and graph checking.
6. **Close priority 4's full behavioral corpus.** Finish naturals,
   options/eithers, folds, conversions, and all 19 supplied-default cases.
   Begin this coverage during earlier deliveries; preserve explicit defaults
   or inhabitance assumptions and independent false controls.

None of the four priorities is complete. Moving the smaller simplification
delivery earlier changes scheduling, not the required contextual capability.

## Why these boundaries matter in Leant

[`ExactFamilyPlan`](../../src/Leant/Synth/Engine.hs) currently documents Djinn's
bounded positive recursive construction and Exference's one-layer elimination.
The same module's `djinnRecursiveProjection` uses `EraseProviderContexts`.
Both are implementation boundaries to address explicitly, rather than evidence
that the requested input cases or contextual Djinn synthesis already work.

[`Leant.Synth.Behavioral`](../../src/Leant/Synth/Behavioral.hs) currently uses
`by decide` for the proposition and its negation. Simplification is proposed
work. A failed tactic must never be converted into a false verdict or a proof.

Native Windows Length support remains a separate platform milestone:
[`Acquire.hs`](../../src/Leant/Synth/Length/File/Acquire.hs) deliberately returns
`LengthFilePlatformUnsupported`. Its acceptance needs acquisition, configured
solver execution, and independent replay together.

Measure cold startup, first accepted result, search work, checking cost, and
memory before choosing a performance change. Semantic provider retrieval is a
useful later scaling investigation when a real query misses a relevant
provider. Shared subgoal graphs, persistent caches, internal cooperative
search, dependent/indexed refinement, and induction remain behind the current
capability work. Native tactic integration and isolated-worker production
routing are separate product/integration milestones with their own acceptance.

The older future-directions reports remain design references; their claims
about missing typed graphs must be reconciled with the current implementation
before using them as a backlog.
