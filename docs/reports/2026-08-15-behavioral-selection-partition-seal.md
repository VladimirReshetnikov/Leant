# Behavioral-selection occurrence partition seal

Date: 2026-08-15

## Outcome

Leant now has an additive structural seal for a future Level-1 hard-selection
path. `Leant.Synth.BehavioralSelection` can accept a total retain/reject
classification of the exact callback-verified occurrences in one bounded
`VerificationBatch`, validate its occurrence association, and return opaque
selected and rejected partitions in original callback order.

This checkpoint deliberately stops before behavioral authority. It changes no
command, startup or contract grammar, ranking order, presentation text, worker
lifecycle, solver query, or candidate set. Main does not invoke the seal, and
the existing Length post-verification adapter remains a permutation-only
ranking path which never prunes. The implementation landed in
`4c61392239f49644de459b8883d9453180111d0c`.

## Additive boundary

The existing `Leant.Synth.PostVerification` seal proves that an assessor
returned a bounded complete permutation of one callback batch. A missing
occurrence is therefore an error, which is exactly right for ranking but
cannot describe an authorized hard rejection.

The new seal keeps selection distinct from that ordering contract. A
successful `BehavioralSelectionBatch candidate retained rejection` owns two
partitions:

- `BehaviorallySelected candidate retained` pairs an original `Verified`
  occurrence with a domain-supplied retention payload;
- `BehaviorallyRejected candidate rejection` pairs an original `Verified`
  occurrence with a domain-supplied rejection payload.

Together the partitions contain every admitted occurrence exactly once. Each
partition is canonicalized to original callback order; the order in which an
adapter proposes decisions has no presentation authority. A later ranking can
be composed explicitly, but this seal does not silently inherit proposal
order.

## Rank-2 occurrence identity

`withBehavioralSelectionInput` projects the opaque receipts from one
`VerificationBatch` and assigns each occurrence one private `Natural` index
inside a fresh rank-2 epoch. The input, candidate handle, decision, selected
receipt, rejected receipt, and batch constructors remain opaque. Nominal roles
cover their epoch, candidate, retention, and rejection parameters as
applicable.

The public `Leant.Synth.BehavioralSelection` facade exposes the input
eliminators, receipt projections, result projections, errors, and seal, but no
retain or reject builder. The only additional construction surface is in
`Leant.Synth.BehavioralSelection.Internal`, where a package-internal domain
adapter may attach a payload to one handle supplied by the current input. Even
that surface exports no handle, decision, selected, rejected, or batch
constructor.

Consequently, safe code cannot manufacture an occurrence, alter its original
index, or move a handle between two fresh input epochs. Equal candidate
payloads still denote separate occurrences because identity is the private
index, not `Eq candidate`. The seal reconstructs each `Verified` value from
the original candidate universe; a decision carries no caller-supplied receipt
which could be substituted or reassociated.

## Bounded validation and precedence

`sealBehavioralSelectionBatch maximumCandidates input decisions` validates in
this fixed order:

1. admit the original candidate-handle spine through the maximum plus one;
2. admit the decision spine through the same maximum plus one;
3. require the decision count to equal the candidate count;
4. in decision order, reject an out-of-range private index before checking
   that index for duplication;
5. sort the validated classifications by private original index and rebuild
   both output partitions from the original receipts.

Range, uniqueness, and exact length together require one decision for every
occurrence. Candidate admission precedes all decision work, so an oversized
input returns its candidate-limit error without evaluating even the decision
spine. Decision admission is productive for a cyclic list and observes only
the maximum plus one. The safe verifier already owns a finite quota-bounded
receipt list, so a cyclic candidate spine cannot be supplied through the
public `VerificationBatch` boundary; the finite maximum-plus-one candidate
case pins the corresponding precedence rule.

Internally, the sealer evaluates each decision only enough to distinguish
retain from reject; the attached payload remains lazy. Candidate payloads
below `Verified` also remain lazy. Count and structural errors therefore do
not acquire accidental behavioral authority by evaluating an explanation,
counterexample, or candidate program.

The out-of-range branch is defensive validation. Both safe decision builders
accept only a handle minted for their abstract epoch, so a malformed
out-of-range witness cannot be constructed through either safe module
surface. The implementation nevertheless checks range before duplication;
the test suite does not introduce an `unsafeCoerce` or raw-index seam merely
to make that unreachable state executable.

## Exact authority boundary

The generic seal establishes only these facts:

- the original candidate and decision spines were admitted under the caller's
  bound;
- every original occurrence was classified exactly once; and
- every selected or rejected wrapper contains the original receipt for that
  occurrence, in its partition's original callback order.

It does not validate the `retained` or `rejection` payload. In particular, it
does not associate an evidence fingerprint, replay a solver model, distinguish
raw `sat`, `unsat`, or `unknown`, impose an unknown or inapplicable policy,
check a Length problem or contract, attest the solver process, or create a
Lean proof. `Verified` still means only that the verification callback
accepted the candidate occurrence. The name `BehaviorallyRejected` describes
the partition selected by a domain adapter; by itself the wrapper is not
evidence that rejection was semantically justified.

This is narrower than the complete selection interface sketched in
`Z3_Behavioral_Synthesis_Proposal.tex`. Proposal-level evidence association,
policy admissibility, explicit unknown/inapplicable handling, diagnostics, and
filter-mode command authority remain later work. A Length adapter must retain
every heuristic, positive, inapplicable, and failed assessment by default and
may construct a rejection only from an exact candidate-associated
counterexample which has survived independent replay. Raw solver status alone
must never become rejection authority.

## Frozen validation

The focused group `behavioral selection occurrence seal` passes 7/7. It pins:

- an empty batch at a zero limit;
- scrambled decisions with both partitions restored to original order;
- missing, extra, and duplicate decision precedence;
- candidate-before-decision admission and productive cyclic-decision capping;
- independent classification of equal-valued occurrences;
- lazy candidate, retention, and rejection payloads; and
- opaque constructors, facade-hidden decision builders, and nominal epoch
  roles.

At this checkpoint `test-unit/Spec.hs` has 17,990 lines and 399 literal
`testCase` tokens. The strict warning-as-error test target builds, the focused
group passes 7/7 in 0.01 seconds, and the complete Leant unit suite passes
398/398 in 36.09 seconds. That frozen test checkpoint is
`4d4592db3efd48b6cc3526be52464b20857f385d`. The implementation and test
commits are recorded separately so the evidence does not pretend to have
existed before its source landed; any later documentation snapshot remains a
separate commit as well.

## Documentation boundary

The current-tree contract is specified by
[`docs/synth-internals.md`](../synth-internals.md) and the source modules. This
dated report records the landing checkpoint and is not a compatibility promise.
Leant remains experimental and is free to revise this surface before a stable
release. The behavioral-synthesis proposal remains forward-looking where it
describes policy, evidence, filtering, CEGIS, sketch search, or proof authority.
