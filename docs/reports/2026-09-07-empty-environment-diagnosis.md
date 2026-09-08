# Exact request correlation and empty-session verification

The first native-verification fix to validate is reuse of the exact empty user
environment. A matched command that timed out after 5.008 seconds without an
environment id completed in 22.336 ms with a materialized empty root. This is
diagnostic evidence; the production reuse change is still pending.

The [durable receipt](../../test-recursive/receipts/request-correlation.json)
records the implementation, validation, complete failed baseline captures,
matched control, and their distinct acceptance boundaries. The
[current re-triage](2026-09-07-synthesis-retriage.md) retains all original
recursive-data, contextual-provider and Church behavior requirements.

## What the trace now records

Set both `LEANT_BACKEND_TRACE` to a fresh local JSON path and
`LEANT_BACKEND_TRACE_REQUESTS=1` to retain request payloads. The existing
event-only trace remains available without the second setting. Request capture
records canonical UTF-8 JSON, the actual backend/request ids, and annotations
provided by the verification callback: role, full requested type, exact candidate,
renderer ordinal, route, and owning engine. Startup and reconstruction requests
may be unlabelled. Compatibility routes do not force an opposing lazy origin.

Capture allows at most 128 records, 256 KiB per payload, 8 KiB per annotation,
and 4 MiB total. An over-bound or invalid-Unicode record is omitted in full,
with explicit accounting. Disabled capture does not demand the annotations or
additional snapshots. No file writes or hashing occur inside request capture.
The existing trace lifecycle writes the final retained data. Canonical UTF-8
payloads describe the protocol value; they are not a claim about physical pipe
byte encoding or producer stdout ownership.

The strict executable and unit build passes with `-Werror`. All 14 focused
backend controls pass in 4.62 seconds. The complete unfiltered suite passes
**686/686 in 357.63 seconds** (357.7597706 seconds for its owned process), with
matching unique inventory and successful rows and unchanged source/executable
identities. These checks validate the diagnostic revision. The earlier
39-cell contextual acceptance retains its own recorded revision and receipt.

## The failed baseline and matched control

The baseline starts in an empty user session. Native append fails in 150.03
seconds: zero passed, ten falsified, three inconclusive. Its separate actual
False control passes in 102.90 seconds with fifteen falsifications and no
inconclusive checks. Both request captures are complete, with no dropped events
or omitted records. Candidate type and positive/negative requests omit `env`;
syntax and some setup requests carry an environment id.

The control prepends only `section` followed by `end` to the same native command
session. The query suffix, providers, executable and bounds remain unchanged.
No declaration, provider, import or option is introduced. This creates the same
implicit-Init user world as a retained REPL environment.

| Identical positive-decision command | Baseline | Materialized-root control |
| --- | --- | --- |
| Actual backend/request | 1 / 11 | 1 / 15 |
| Candidate | `fun _ _ _ => List.nil` | `fun _ _ _ => List.nil` |
| Environment field | absent | `env: 2` |
| Duration | 5.008023501 s | 0.0223364 s |
| Terminal event | request timeout | parsed response |

The command SHA-256 is
`00ac53da709c3ae4215fee8d6a790247c97b0fe64f3e1647c94801f5bdd6098c`.
Both command text and callback annotation are identical. Independently decoded
payloads differ only by the control's `env: 2`; the receipt includes their
separate byte counts and hashes.

The control's append query passes in 24.85 seconds, displaying
`fun f x y => f _ (.cons) y x`. Independent full-type kernel replay passes,
including the behavior proposition, with three empty axiom inventories. This
runner records the toolchain-qualified launcher; it does not separately pin
the resolved kernel executable. The control's False query passes in 10.19
seconds with 87 falsifications and no inconclusive checks. Its trace retains
128 requests and explicitly omits 187 at the row cap. Consequently the diagnostic
wrapper exits with failure for incomplete capture even though the underlying
behavioral acceptance passes. The positive capture is complete: all 54 candidate
checks use `env: 2`.

## Source explanation and next acceptance

`buildImportedBase []` returns no environment. Temporary behavioral checks do
not advance the real user environment, so their payloads repeatedly omit `env`.
The installed REPL's `runCommand` then enters `processInput` with a fresh header
cache; its frontend invokes header/import initialization again. This confirms
repeated initialization. Physical `.olean` rereads and a transport defect are
not established by these observations.

The proposed production change materializes an empty command once and retains
its environment id separately from the real user environment. Existing user
state must take precedence. The root must never grant synthesis-helper names,
change user history or import semantics, or survive backend/session invalidation.
Initial acquisition belongs to cold setup; recovery during an active query
must use only its remaining request allowance.

Acceptance still requires the original append/length queries without the
`section`/`end` prefix, unchanged bounds, actual False controls, independent
exact replay, empty-session reuse and namespace isolation, reset invalidation,
and backend retirement/reconstruction. This diagnostic milestone changes no
proof method, candidate window, timeout policy or synthesis acceptance rule.
