# Command-authorized replay-backed Length filtering

Date: 2026-08-15

## Outcome

Leant now implements the first command-level hard-filter slice from the Z3
behavioral-synthesis proposal. One `:synth` command may explicitly choose
`--behavior-mode filter` and omit a callback-verified scalar or canonical-
`Prod` occurrence only when the existing Length pipeline produced an
independently replayed counterexample for that exact occurrence. Ordinary
commands and contract-only commands without an explicit behavior mode retain
the established complete stable ranking operation; without an activated
policy, ordinary ranking remains the lazy identity.

The generic total-partition seal landed in
`4c61392239f49644de459b8883d9453180111d0c`, with its structural
characterization in `4d4592db3efd48b6cc3526be52464b20857f385d`. The nominal
scalar and pair Length selection adapters landed in
`ff4cd6cdf34c1959d85938b289033fa9ca41cb12`, with their replay-authority
characterization in `9aa6dc969bd382e3e501a98c3adc8c0f3a4ed5f3`. The command,
Integration, presentation, and Main connection landed in
`822a79df5e3e5b74d7d4853d9a9ee1c8902e093c`.

This checkpoint changes no startup or contract-only JSON shape, solver query,
evidence fingerprint, executable policy, replay algorithm, candidate grammar,
or Lean verification gate. It adds an explicit consumer of the existing exact
replay evidence. Leant remains experimental and makes no stability or backward-
compatibility promise; this report records the current contract rather than
freezing it.

## Exact command grammar

The option-bearing grammar is:

```text
:synth [--behavior-mode rank|filter] [--length-contract ABSOLUTE-PATH] -- TYPE
```

Ordinary `:synth TYPE` remains delimiter-free. The mode, when present, must
precede the contract. Every recognized option form requires the standalone
`--`, after which goal text remains opaque. Omitting the mode means `rank`.

Only exact tokens are options. `--behavior-model` and
`--length-contractual`, for example, remain ordinary goal prefixes. An exact
behavior option with no value, `--` as its value, or a value other than `rank`
or `filter` is rejected. Missing delimiter is rejected for either option form.
For a contract form, an empty path wins before a misplaced mode; otherwise an
exact mode token inside the path span is rejected because behavior mode must
come first. A path may contain spaces, while a standalone `--` ends it.

The six intended command forms are:

| Form | Behavior and authority |
| --- | --- |
| `:synth TYPE` | rank with the startup contract; lazy identity when assessment is disabled |
| `:synth --behavior-mode rank -- TYPE` | the same rank choice made explicit |
| `:synth --behavior-mode filter -- TYPE` | filter with the startup contract; requires activated policy |
| `:synth --length-contract PATH -- TYPE` | rank with a command-local passive contract; requires activated policy |
| `:synth --behavior-mode rank --length-contract PATH -- TYPE` | explicit rank with that command contract |
| `:synth --behavior-mode filter --length-contract PATH -- TYPE` | filter with that command contract |

## Authority before IO

`LengthBehaviorMode` is a closed `LengthBehaviorRank` or
`LengthBehaviorFilter` choice. `Leant.Synth.Length.Integration` retains it in
the opaque startup or explicit `LengthAssessmentRequest` beside exactly one
activated `LengthRankingPolicy` and one lazy scalar-or-pair passive contract.
The parsed mode is not inferred from the contract or Lean goal.

Disabled rank without a command contract is the existing non-strict identity.
Disabled filter returns
`LengthAssessmentFilteringRequiresActivatedPolicy`. For a command contract,
Main asks Integration for opaque permission before it admits the path or
performs file IO. Disabled rank receives the existing explicit-contract
activation refusal; disabled filter receives the filtering refusal. A passive
contract cannot activate execution, and `filter` cannot select an executable,
pin policy, solver budget, artifact policy, replay limit, or ranking strategy.

After permission and the one bounded file read, the request stays on the
command stack through ordinary, universe-retry, provider, and classical lanes.
Behavior mode, command contract, replay inputs, and selection results never
enter `ReplState`, history, snapshots, or a cache.

## Nominal replay-only decision taxonomy

`Leant.Synth.Length.Selection` and
`Leant.Synth.Length.SpinePair.Selection` run the existing scalar or pair
assessment pipeline. Each ranked report retains its safe original callback
index, which the adapter uses to recover the matching private handle in one
fresh behavioral-selection epoch. The adapter classifies every occurrence:

- candidate-local preparation refusal is retained with its bounded refusal
  class;
- `Unassessed` is retained;
- `Heuristic status` is retained for `sat`, `unsat`, and `unknown` alike;
- `BoundedPositive` is retained with the exact independently completed input-
  box receipt;
- `ApplicableDomainEstablished` is retained with its exact independently
  completed applicable-domain receipt; and
- only `Counterexample` is rejected, with its independently replayed final
  receipt and optional simplification metadata.

Preparation refusal is checked before assessment classification. The scalar
and pair retention, rejection, failure, and result types are nominally
distinct. The adapter adds no evidence constructor and trusts no raw solver
status. The generic `BehaviorallyRejected` wrapper is structural association,
not behavioral authority; only the domain adapter's private replay-only
rejection payload makes the current decision admissible.

## Total partition and preserve-all failures

`withBehavioralSelectionInput` mints opaque occurrence handles under a fresh
rank-2 epoch. The public facade exports no decision builder. The package-
internal Length adapters can attach a retention or rejection payload only to a
handle supplied by that input; they cannot manufacture or reindex one.

`sealBehavioralSelectionBatch` bounds the original occurrence spine and the
decision spine, requires one decision per occurrence, checks range before
duplication, and reconstructs the exact original `Verified` receipt. Selected
and rejected partitions are each returned in original callback order,
independent of decision order and the assessment ranking permutation. Equal
candidate texts remain separate occurrences. Filter mode therefore returns a
stable survivor subsequence; it does not silently rank the survivors.

Every post-verification failure, ranking failure, missing ranking, impossible
original-index mismatch, candidate/decision admission failure, or seal failure
returns one opaque preserve-all result containing the literal original batch.
No partial selection or rejection wrapper escapes. `lengthAssessmentCandidates`
projects survivors on success and the original candidates on failure, while
ranking and selection projections remain disjoint. Main reports a mode-neutral
warning that behavioral assessment preserved all verified candidates.

## Presentation and all-rejected handling

Presentation traverses the associated wrappers directly. It never joins
candidate text to a detached evidence list by position or spelling. A retained
input-box or applicable-domain receipt keeps the existing positive note. A
rejected occurrence uses the established bounded counterexample or
counterexample-simplification renderer verbatim.

Main binds only survivors as `it1`, `it2`, and so on, and prints each omitted
occurrence separately as `rejected` with its exact note. A partial selection
therefore cannot leave a rejected term reachable through a newly generated
splice. An accepted all-rejected batch is a handled synthesis result: Main
prints the rejections, creates no new `itN` binding, clears `rsSynthIts` and
`rsSynthItsProve`, and returns before the unrelated “none survived Lean
verification” fallback.

## Replay-bank scope

The selection adapters reuse the existing assessment runner and its four-entry
newest-first MRU input-vector bank. The bank stores no solver status, verdict,
receipt, query, provider-law basis, or proof. A vector learned from an earlier
candidate can reject a later candidate only after Djex independently evaluates
and associates it with that later candidate's exact query. A new assessment
batch starts empty. This checkpoint deliberately adds no persistent sample
bank and no CEGIS loop.

## Validation boundary

The adapter checkpoint already pins live scalar and pair selection, exact
replay-only rejection, retention of every heuristic status and positive class,
preserve-all failures, original-order partitions, nominal domain separation,
and invocation-local MRU state. The command-focused tests additionally pin the
exact parser matrix, disabled-before-IO authorization, scalar and pair
dispatch, disjoint result projections, association-safe presentation, and
Main's survivor-only and all-rejected control flow.

The command characterization is frozen in
`aebb9c6a1a34a7a6fe527c73ea3c368be42d2532`. At that checkpoint:

- `test-unit/Spec.hs` has 19,065 lines and 410 literal `testCase` tokens;
- its SHA-256 digest is
  `e04d2bbbfbb211a4d0f83948d7c475409f705876e561ea4f620bfabbce1c371c`;
- the focused exact command-parser case passes 1/1;
- the `explicit Length assessment integration` group passes 14/14;
- the complete unit suite passes 409/409; and
- the strict warning-as-error test target and executable both build cleanly.

The production and test commits remain separate so the evidence does not claim
to predate the source it characterizes. The final documentation source pin and
rendered-document measurements are recorded only after the documentation
snapshot is frozen.

## Documentation boundary

Current behavior is specified by the
[Length behavioral reference](../length-ranking.md), the
[`synth` internals map](../synth-internals.md), and current source. The earlier
[behavioral-selection report](2026-08-15-behavioral-selection-partition-seal.md)
correctly records that its structural landing checkpoint was not yet connected;
that historical statement is superseded for the current tree by this report.
The Z3 proposal remains forward-looking for persistent CEGIS, typed sketches,
sound prefix pruning, more domains, and proof production.
