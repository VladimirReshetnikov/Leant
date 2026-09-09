# Complete request deadlines pass native integration

Leant now applies one absolute deadline to request preparation, sending and
response handling. Annotation evaluation, JSON encoding and a blocked pipe
write can no longer consume an unbounded interval before the response timeout
starts. The strict executable/test build and all ten integration gates pass.

## Request ownership and cancellation

The deadline starts before capture or encoding. Sending and response handling
consume the remaining time from that same monotonic deadline; each phase does
not receive a fresh budget. Timeout arithmetic uses unbounded integers before
clamping the remaining microseconds to the runtime's machine integer range.

Windows pipe writes can defer asynchronous exceptions while the reader remains
open. An owned sender task therefore performs capture, encoding, writing and
flushing. If sending exceeds its deadline, Leant terminates and reaps the backend
before joining the sender, so neither a blocked writer nor a partial protocol
message survives a returned timeout. Interruptions during sending also retire
the backend. Ordinary response timeouts retain the existing caller-owned
retirement path and late-response ownership behavior.

Successful requests retain their capture schema, canonical payloads, request
and backend identities, and stage ordering. Request capture still requires its
explicit opt-in; disabled capture does not evaluate annotations. Transport,
malformed-JSON and timeout outcomes remain distinct.

## Validation

Three regressions reproduced the original defects: blocked annotation
evaluation, blocked payload evaluation with capture disabled, and a 1 MiB write
to a backend that does not read stdin. All three originally escaped the
one-second request deadline; the blocked write also delayed cancellation until
the helper's ten-second sleep ended. With the repair, each returns the request's
own timeout in about one second, within the independent three-second guard.

The complete 705-test unit run passes, including those cases and the existing
capture, lifecycle, interruption and late-response checks. Its exact source and
executable hashes were verified before retention in the native integration run.

| Gate | Accepted coverage |
| --- | --- |
| Unit | 705/705 tests, complete inventory |
| Global methods | Six ordinary/behavioral cells and exact replay |
| Method controls | Nine False/cache sessions with actual request correlation |
| Local context | 39 cells, including 18 exact displayed-output replays |
| Simplification | 15 queries with their fixture controls and replay |
| Native List recursors | 12 cells across Djinn/Exference/Both; nine exact positive replays and three completed False controls |
| Extended Lean Exference | All 13 operations and one completed False control |
| Nested foralls | Nine cells; six exact positive outputs and three False controls |
| Native Djinn signatures | 350/350 candidates, axiom-free full-type kernel replay |
| Native Exference signatures | 350/350 candidates, axiom-free full-type kernel replay |

The initial native attempt passed the method positives, then stopped before
any method-control session because the control runner pinned the old backend
source. After reviewing the unchanged capture contract and the intentional
deadline changes, the runner's exact source pin was refreshed. It now also
records that reviewed hash in its receipt. The guard, semantic checks and
original query limits remain enforced. The second attempt completed eight native
gates but was interrupted during the final Exference corpus; a third attempt
also ended without its terminal receipt. Their termination cause is unknown.
The fourth attempt retains those eight completed gates and the unit result only
after exact input checks, then completes the entire Exference corpus afresh.
The final production/source/runtime integrity comparison passes. Earlier
interruption records remain historical evidence, not successful full runs.

The earlier [diagnostic checkpoint](2026-09-09-synthesis-after-deadline-trace.md)
and its archive preserve the baseline failures and stale-pin preflight failure.
Those outcomes are not relabeled as passing behavioral controls.

## Reproducible evidence and limits

The [acceptance receipt](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/request-deadline-integration.json)
and [source/run archive](https://github.com/VladimirReshetnikov/Leant/blob/main/test-recursive/receipts/request-deadline-integration.zip)
record exact commands, inventories, fixture bounds, complete child captures,
source identities, executable identities and independent replays. Every archive
member and its SHA-256 were checked again when packaging.

The tested backend source SHA-256 is
`175a93f83363f34bc24a76bd9b7a07eee84cec17f4bd2e996bb511278d97116a`.
Leant retains the tested Djex dependency `bfc3692e`; this run does not promote
or certify newer canonical Haskell frontend changes.

This closes delivery 0 of the [current re-triage](2026-09-09-synthesis-after-one-shot-acceptance.md).
The next native milestone is integration of an exact accepted canonical Djex
revision. Remaining public contextual forms and the full 160-cell Church behavior
worklist follow, with a bounded native tree investigation. Native tree
synthesis remains unaccepted in all three modes. Deadline correctness and
signature inhabitation do not establish tree construction or complete behavior.

Archive SHA-256: `5edf4ae899c7783047cb8fc2bfc5aac833542a82e6d2f506f3238f3e8aade778`.
