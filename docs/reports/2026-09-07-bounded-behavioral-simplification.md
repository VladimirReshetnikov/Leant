# Bounded behavioral simplification

The named `:synth f : TYPE where PROP` path now tries bounded simplification
when neither the proposition nor its negation can be decided. The order is
positive `decide`, negative `decide`, positive `simp`, negative `simp`. Each
attempt checks the same exact candidate at the complete requested type. A
successful proof stops the sequence; a transport failure stops it with an
inconclusive result. The decision-only library helper retains its old behavior.

The simplification program uses `solve` around `simp`: partial progress cannot
become acceptance. It permits 10,000 simplifier steps and 200,000 Lean heartbeats.
The existing five-second request maximum and shared command deadline cover the
additional attempts.

## Acceptance

The GHC 9.12.4 build of `exe:leant` and `test:leant-synth-tests` passed with
`-Werror`. All 17 focused host-behavioral tests passed, including proof order,
short circuiting, transport failure at every stage, exact source preservation,
and the distinction between a proved negation and an unfinished proof.
The enumerated, unfiltered boundary run passed **619 of 620 tests** in
806.95 seconds. The existing polymorphic-layer recovery test failed because
its named-binary provider stage exceeded 30 seconds. Its unchanged focused
retry passed in 133.11 seconds, retaining that same internal limit. All source
and executable hashes matched the full run. The
[full-run receipt](../../test-behavioral/receipts/unit-incomplete.json) and
[focused retry](../../test-behavioral/receipts/unit-focused-retry.json) are
separate: this is not a passing unfiltered 620-test run. The same timeout had
also occurred before this change with a subsequent passing unchanged retry;
its precise timing cause remains unmeasured.

The [live receipt](../../test-behavioral/receipts/simplification.json) records:

- Sixteen isolated Lean 4.32.0 proof-method controls. Quantified positive and
  negative examples reject both decision attempts and close only at the
  expected simplification polarity. Opaque and partially simplified goals
  remain unproved. Parser or import failure cannot satisfy a negative control.
- Fifteen live queries, five each under Djinn, Exference, and Both. Each mode
  passes the quantified identity assertion, proves the negative control false,
  reports opaque and partial cases inconclusive, and subsequently passes an
  ordinary decision query. No implementation providers enter these queries.
- Six independently replayed exact displayed terms and their assertions.
  Every candidate has an empty axiom inventory. The three quantified proofs
  use exactly `propext` and `Quot.sound`; the three ordinary decision proofs
  have empty inventories. No accepted replay uses `Classical.choice`,
  `sorryAx`, or a user axiom.
- Unchanged source and executable hashes. Settings were a 32-candidate window
  and verification allowance, 4,096 Exference steps, 20,000 Djinn choices,
  and a 30-second command deadline. The live process took 152.29 seconds across
  all queries, including the separate environment preparation stage.

Original captures remain under `dist-newstyle/simp-acceptance/all-engines-v1/`.
Build and focused-suite logs are `dist-newstyle/priority-simp-build.log` and
`dist-newstyle/priority-simp-focused-tests.log`. The
[runner guide](../../test-behavioral/README.md) explains reproduction and the
proof-inventory policy.

## Remaining boundaries

This validates the bounded proof fallback at Djex dependency
`3ce26cfd966ea4da2300028880c71ddaae50596d`. It does not establish complete
ordinary recursive-data behavior under Exference/Both, supplied recursor
synthesis, contextual dictionary support, or the broader Church behavioral
corpus. Those remain in the [active re-triage](2026-09-07-synthesis-retriage.md).
Proofs establish the supplied proposition relative to the current Lean
environment; finite examples do not establish an unstated universal law.
