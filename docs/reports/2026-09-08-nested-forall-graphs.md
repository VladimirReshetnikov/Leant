# Closed source graphs for nested polymorphic results

Accepted 2026-09-08. The [publication receipt](../../test-church/receipts/priority4-nested-forall-graphs.json)
preserves the exact raw native and unit receipts, replay inputs, complete test
inventory, build logs and failure history.

Leant now uses Djex `a44f70570c9287d3fc377e9df18978e1c6a692fa`, whose
[forall-graph update](../../lib/Djex/docs/reports/2026-09-08-exference-forall-graphs.md)
retains original root quantifiers, nested forall introductions, constructor
instantiations and exact Exference lambda projection. The frontend already
keeps each candidate's own graph through typed rendering, Both and Length;
this integration needs no new search or rendering policy.

The native acceptance passes **9/9 cells** for the complete type
`{α : Type} → α → {β : Type} → β → β`. Ordinary and named-`where` synthesis
pass in Djinn, Exference and Both. Every accepted output is independently
replayed at that full type, with four cross-instantiation observations using
Nat/Bool, Bool/Nat, Nat/Nat and Unit/List Nat. There are **six exact outputs,
24 finite observations and 16 empty axiom inventories**, including the
independent oracle and its wrong-result and False controls. Each engine also
passes an actual live `where False` query, without an accepted output or an
inconclusive behavioral check.

Each displayed variant retains its actual engine, renderer alternative,
closed graph root and exact compatibility erasure. Both forall introductions
have distinct node, occurrence and opened-variable identities. Their source
types and opened bodies match their actual graph nodes and children. The
outer introduction is the root. No global provider or dictionary evidence
enters this context-free query.

`CandidateObservation` exposes these forall witnesses and implicit
type-application selections only in the existing opt-in diagnostic output.
The data comes from the same retained graph; it does not create new checking
authority. Lean still checks the exact emitted term independently.

The [reusable native harness](../../test-church/nested_forall_probe.py) starts
nine fresh sessions with no user declarations, imports or providers. Its
limits remain window 60, verification 12 per lane, 4096 steps, queue 1024,
depth-first traversal, the default unbounded Djinn choice budget and a
20-second command timeout. The display quota is one. A separate 120-second
process guard includes environment startup. Both retains its ordinary
per-lane verification policy. No retry, candidate refill or larger search
budget is added. Sources, runtimes, commands, captures and generated replay
files remain unchanged throughout acceptance.

The strict GHC 9.12.4 build passes with `-Werror` and one build job. The
first complete unit run reports three failures out of 686: stale assertions
expecting an unavailable nested graph or free rigid variables at the graph
root. Their replacements require the complete closed request, exact typed
ownership and erasure; the nested-result test also requires both introduction
sites. The unchanged explicit-absence and failed-typed-render controls still
guard the compatibility boundary. All three corrected fixtures pass in a
focused run. The final unfiltered suite passes **686/686 in 358.12 seconds**
(358.90 seconds for the owned process), matching its complete unique inventory.
Source, test executable and fake-Z3 helper hashes remain unchanged and were
rechecked before publication.

An initial harness setup attempt stopped before any runtime process because
the kernel-pinning helper received a string instead of a `Path`. The fresh
nine-cell run uses the corrected argument, preserving the same source type,
observations and limits. The setup failure and first unit failures remain
separate from the successful native matrix.

This milestone confirms the frontend integration of stronger source evidence.
It adds no extended Church operation to the behavioral coverage count. The
canonical supplied `maybeEither` witness passes checking and GHC replay, but
its unchanged live Exference window still yields 256 false candidates, zero
errors and zero timeouts. The next search work is to inspect that exact prefix
and the `foldl1` construction path. Broader supplied folds and trees, described
global contextual providers, selected dictionary identity and the complete
13-operation/19-default behavioral matrix remain required by the
[current re-triage](2026-09-07-synthesis-retriage.md).
