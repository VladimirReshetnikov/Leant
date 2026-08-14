# Exact counterexample presentation

> **2026-08-14 follow-up.** Presentation now also handles
> `BoundedPositive !ValidatedLengthInputBox`. The associated
> `renderLengthInputBoxValidationNote` reports the inclusive maxima with bounded
> rendering, checked
> and precondition-applicable assignment counts, provider-count-only basis, and
> explicit zero-applicable vacuity under the same 384-character ceiling. See the
> [unsat-triggered bounded validation report](2026-08-14-unsat-triggered-length-input-box-validation.md).
>
> **Later 2026-08-14 follow-up.** A version-3 origin hit produces the same
> ordinary associated `Counterexample` and therefore uses this unchanged
> counterexample note. An origin miss or indexed atomic failure produces no new
> semantic presentation. See the
> [origin-probe orchestration report](2026-08-14-length-origin-probe-orchestration.md).

## Scope

Leant already retained an independently replayed Length counterexample beside
the exact callback receipt which produced it. The occurrence seal preserved
that association through stable demotion, but Main projected only candidate
text and discarded the semantic result before display.

This checkpoint completes that opt-in edge without changing Djex, the default
path, solver execution, ranking, fingerprints, or schemas.

## One associated presentation source

`Leant.Synth.Length.Integration.lengthAssessmentRanking` exposes the ordinary
receipt-bearing ranking only after the existing occurrence seal. Disabled mode
and rejected configured input return no ranking without inspecting the lazy
verification batch.

`Leant.Synth.Length.Presentation` consumes each whole opaque
`RankedLengthCandidate` and creates one opaque candidate presentation. Its text
comes from that ranked receipt's verified candidate, and its optional note
comes from the assessment attached to the same receipt. Main uses one ordered
presentation list for Lean bindings, splices, and `itN` output. It never zips a
candidate list with a separately projected evidence list, so equal spellings
and reordered occurrences cannot borrow one another's note.

`Counterexample` and `BoundedPositive` produce their distinct associated notes.
`Heuristic`, `Unassessed`, disabled assessment, rejected input, and the
original-order atomic fallback produce no semantic claim.

## Sanitized bounded claim

The note says that the result is a replayed, model-relative finite-list-spine
Length counterexample. It renders input and result **spine lengths**, not Lean
values or source-language execution. A provider-backed basis becomes only
"conditional on N assumed provider laws used by this candidate"; the note
never projects or renders the receipt's private Djex provider-name list.
Provider-independent evidence is named
explicitly.

The version-1, version-2, and version-3 startup files admit at most eight
inputs, 256 provider laws, and 4,096-bit evaluation values. Presentation
renders at most eight inputs, shows
ordinary naturals exactly only through 24 decimal digits, and replaces larger
ones with a bounded bit-length summary such as `<4096-bit natural>`. A valid
configured note is bounded by the hard 384-character terminal ceiling.
This is presentation sanitization, not evidence erasure: the replayed receipt
and its exact association remain available inside the ranking result.

The positive note is deliberately different. It calls the input box
independently checked and bounded/model-relative, renders each configured
inclusive maximum, the exact completed assignment count, and the count for which
the precondition held. A zero applicable count is labeled vacuous within the
box. It never mentions the `unsat` observation which merely scheduled the
independent traversal, and it makes no claim outside the explicit box.

The counterexample note explains stable demotion; the positive note records a
neutral bounded assessment. Neither proves the other candidates, prunes a
candidate, attests Z3, verifies an assumed provider law, or establishes concrete
Lean behavior.

## Validation

Focused regressions cover:

- disabled-mode laziness and no ranking;
- configured reordered text/evidence association;
- equal candidate occurrences across stable demotion;
- actual private provider-name non-disclosure;
- provider-independent and provider-conditional wording;
- non-vacuous and vacuous bounded-positive wording and exact counts;
- status-only, rejected, and atomic-fallback no-note behavior;
- 4,096-bit value summarization and the terminal note bound;
- forbidden source-language, proof, correctness, and solver overclaims.

The existing no-option path remains byte-for-byte unchanged because disabled
assessment yields the same candidate text list with every note absent.
