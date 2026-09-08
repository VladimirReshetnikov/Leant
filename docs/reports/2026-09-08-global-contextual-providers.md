# Global contextual providers through complete source schemes

The global-method integration passes its complete acceptance gates: six native
method cases, nine cache/False sessions, the existing 39-cell local-context
matrix, a strict build and all 701 Haskell boundary tests. This accepts the
bounded Type-0 method route described below; broader contextual synthesis and
the full Church coverage goal remain open.

## Implementation

Leant now carries a discovered provider's complete closed source scheme,
structured Lean name, binder visibility and class constraints into contextual
search and reconstruction. The pinned dependency is Djex `4a4ed0fc`, whose
unique lexical-Given inference resolves a provider parameter occurring only in
its class constraint. It does not change a goal's rigid type variables.

For example, the actual class projection `Ctx.C.out` can implement the original
goal `∀ (α : Type), [Ctx.C α] → Nat`. No extra value argument of type `α` is
added to make inference easier. The public regression declares only the class,
discovers its real method, and checks dictionaries carrying 7 and 11 at Nat and
Bool. Ordinary and named-`where` queries work in Djinn, Exference and Both.
The [runnable fixtures](../../test-context/global-methods/README.md) retain all
settings and commands; reference implementations are checked in separate Lean
processes and never become search providers.

Provider preparation rejects open or unsupported schemes, duplicate owners,
conflicting source declarations, namespace substitutions and changed private
schemes. Typed global nodes receive rendering authority only from their exact
provider packet. The existing restrictions on extra premises and changed
fitting goals remain. Projection discovery uses Lean's actual class and
structure metadata, excluding ordinary structures, namespace siblings and
superclass subobject projections from this method increment.

The legacy provider-cache key does not record source-wire mode. Contextual
provider discovery therefore bypasses its reads and writes; ordinary discovery
keeps its existing cache behavior. Six same-session regressions use the same
provider-query key before, during and after a contextual visit, require an
actual owned `Nat.add` implementation on both legacy queries, and independently
replay all three displayed outputs.

## Exact verification traces

Ordinary candidate verification now uses the same optional diagnostic fields
as behavioral verification: the exact requested type, candidate text, engine,
route and renderer ordinal. The annotation is created at the actual callback
and remains lazy when capture is disabled. Command payloads, environment
recovery, request timeouts and synthesis admission are unchanged.

The default capture still retains at most 128 whole request records. Exference
needed 395–398 records and Both needed 427–430 in these cache sessions, so the
runner explicitly selects 512 using `LEANT_BACKEND_TRACE_REQUEST_LIMIT`.
The production constructor clamps the requested count to 0–1024. The original
256 KiB payload, 8 KiB annotation and 4 MiB aggregate UTF-8 limits remain.
Every snapshot records the actual cap; incomplete capture still fails the
validator. The expanded setting affects diagnostics, not search or verification
budgets. Two new Haskell controls cover later request ownership, unchanged
transport, clamping and omitted-metadata laziness.

The repository-local runner removes dependencies on historical files under
`dist-newstyle`. Its capture checks preserve exact request/backend identity,
terminal response and cleanup, canonical bytes, and omission accounting.
Eleven adversarial Python controls cover substituted candidate or backend
identities, missing responses or cleanup, duplicate records, omitted data,
incorrect byte accounting and a mismatched selected capture limit.

The existing local-context runner now pins the actual backend, Lake/kernel
executables and runtime project metadata as well as source and replay inputs.
External runtime paths are hashed with absolute keys instead of being forced
under the repository root. Its 14 parser/ownership/replay controls pass, and
its original 39 cases, expected outcomes and search bounds are unchanged.

## Validation and retained diagnostics

The [integration receipt](../../test-context/receipts/global-method-integration.json)
and its [compressed archive](../../test-context/receipts/global-method-integration.zip)
record the complete results, commands, process
captures, source/runtime hashes, exact request traces and replay files.

| Check | Result |
| --- | --- |
| Strict executable, test and helper build | Pass with `--ghc-options=-Werror`, serial execution. |
| Focused backend tracing | 16/16 pass, including the two new capacity controls. |
| Python acceptance controls | 14 production controls and 11 trace controls pass. |
| Actual method discovery and synthesis | 6/6 native ordinary/where cases, six exact full-type replays, 24 finite observations, 30 empty candidate replay inventories. |
| Cache and actual False controls | 9/9 sessions, 21 independent replay files and 106 empty replay inventories. Every capture is complete; zero omitted records and dropped events. |
| Existing local-context matrix | 39/39: 18 exact candidate replays with 72 finite observations and 144 empty replay inventories, three actual False controls and 18 explicit metadata refusals. |
| Complete Haskell boundary suite | 701/701 pass in 370.42 seconds (370.63 seconds owned process time); complete inventory and unchanged source/executable hashes. |

The cache queries explicitly use a 32-candidate/verification window. The
original four-slot workload was rerun on the same final executable and still
fails to find its required legacy implementation. That failed diagnostic is
retained; passing at 32 does not count as success at four. Steps and choice
budget remain 20,000, the provider cap remains one, and the query deadline
remains 45 seconds. No product search defaults are increased.

The earlier 128-record supplemental run succeeded through the Djinn sessions
but exceeded the capture cap in Exference, omitting 267 records. It remains a
failed diagnostic despite finding matching implementations. A new full run
with the explicitly selected 512-record cap closes the capture gate. The
receipt also retains the earlier 699-test pass and the local-runner bookkeeping
failure. The first final-suite run passed 700/701 with a deadline miss in an
existing Length-ranking test. That test then passed in isolation and in the
complete 701/701 rerun, with no change to its source or budgets. The earlier
results do not substitute for that complete rerun.

## Remaining priorities

This is a bounded global-method increment in original priority 3. It does not
complete that priority or the wider priorities 1–4 goal. Mixed inventories
containing unsupported source packets still fail explicitly: in the existing
metadata control, `ContextProduction.Dictionary.mk` cannot yet be represented
as an ordinary dictionary-valued source scheme, although its `tag` projection
and the Token providers have complete packets. Such inventories need further
source representation/admission work; increasing the provider cap does not
solve that boundary. Equal-predicate dictionary selection, conditional
providers, superclass derivation and richer universes also remain open.

The next frontend delivery is Haskell loaded-provider admission/source-scheme
transport and implicit-root behavioral scoping. Missing Church construction
paths and the supplied tree-accumulator fixture remain required work. This
increment adds no Church behavioral cells or tree-fold acceptance. The full
13 extended operations and all 19 explicit-default counterparts, across both
Haskell engines and all three Lean modes, remain in the goal.
