# Exact counterexample presentation

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

Only `Counterexample` produces a note. `Heuristic`, `Unassessed`, disabled
assessment, rejected input, and the original-order atomic fallback produce no
semantic claim.

## Sanitized bounded claim

The note says that the result is a replayed, model-relative finite-list-spine
Length counterexample. It renders input and result **spine lengths**, not Lean
values or source-language execution. A provider-backed basis becomes only
"conditional on N assumed provider laws used by this candidate"; the note
never projects or renders the receipt's private Djex provider-name list.
Provider-independent evidence is named
explicitly.

The version-1 file admits at most eight inputs, 256 provider laws, and
4,096-bit evaluation values. Presentation renders at most eight inputs, shows
ordinary naturals exactly only through 24 decimal digits, and replaces larger
ones with a bounded bit-length summary such as `<4096-bit natural>`. A valid
configured note is bounded below the regression allowance of 360 characters.
This is presentation sanitization, not evidence erasure: the replayed receipt
and its exact association remain available inside the ranking result.

The note explains why an opted-in ranking demoted a candidate. It does not
prove the other candidates, prune the demoted candidate, attest Z3, verify an
assumed provider law, or establish concrete Lean behavior.

## Validation

Focused regressions cover:

- disabled-mode laziness and no ranking;
- configured reordered text/evidence association;
- equal candidate occurrences across stable demotion;
- actual private provider-name non-disclosure;
- provider-independent and provider-conditional wording;
- status-only, rejected, and atomic-fallback no-note behavior;
- 4,096-bit value summarization and the terminal note bound;
- forbidden source-language, proof, correctness, and solver overclaims.

The existing no-option path remains byte-for-byte unchanged because disabled
assessment yields the same candidate text list with every note absent.
