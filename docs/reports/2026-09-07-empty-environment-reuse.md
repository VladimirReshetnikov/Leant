# Reuse the exact empty user environment for behavioral checks

Temporary behavioral checks now reuse the ordinary implicit-Init environment
when the real user session has no environment id. Native append and length pass
their original public queries and bounds, exact Lean replay, and actual False
controls. The strict build and complete **686-test suite pass**. The
[acceptance receipt](../../test-recursive/receipts/empty-user-environment.json)
records the exact source, commands, process ownership and validation boundaries.

This implements the fix selected by the
[request-correlated diagnosis](2026-09-07-empty-environment-diagnosis.md).
Append's new command files are byte-identical to the failed baseline, with
identical settings and no `section`/`end` prefix.

## Environment ownership

`rsEmptyUserCheckEnv` retains an id returned by a checked empty Lean command.
An existing `rsEnv` always takes precedence. The cached root is separate from
the user's current/base environment, history, undo stack and imports; it never
borrows the richer synthesis environment. An absent user environment with
nonempty session provenance is refused rather than replaced with an empty one.

Initial acquisition runs with existing cold setup, before the behavioral query
clock starts. If an active query needs a replacement root after recovery, it
uses only the remaining request allowance; the actual check recomputes that
allowance afterward. Backend death and session reconstruction invalidate the
root through the existing derived-environment boundary. No proof method,
candidate quota, search bound or deadline policy changes.

## Public lifecycle acceptance

Four independent bounded sessions pass, totaling eleven queries. Their exact
command fixtures are retained under
[`test-recursive/fixtures/empty-user-environment`](../../test-recursive/fixtures/empty-user-environment).

| Session | Observed behavior | Complete captured requests |
| --- | --- | ---: |
| Reuse and isolation | Two False queries reuse one root; the real environment remains absent. Ordinary commands reject `Lean.Environment`, `LeantSynth.esc` and `it1`. A real subsequent import succeeds. | 23 |
| User state and recovery | Actual `UserSentinel` state overrides the cached root. A one-second sleep timeout retires the backend; reconstruction restores the declaration and a successful context-dependent query. | 59 |
| Reset | Reset removes the declaration and invalidates the root. A replacement root is created and reused by the next successful query. | 28 |
| Empty-state recovery | A one-second sleep timeout occurs before any real declaration. Two distinct backend epochs acquire their own roots, and the replacement root is reused. The real user environment remains absent. | 27 |

All four traces have zero dropped events and zero omitted records. The four
accepted implementations retain their exact typed graph and rendering owner,
then pass independent full-type and predicate replay with **ten empty axiom
inventories**. This lifecycle runner directly resolves and hashes the Lean
kernel executable. The remaining seven queries establish actual False rejection.

## Native supplied-fold acceptance

| Original public workload | Positive result | Observations | Live process |
| --- | --- | --- | ---: |
| Append | `fun f x y => f _ (.cons) y x` | 1 passed, 17 falsified, 0 inconclusive | 34.92 s |
| Generalized length | `fun f x g y => f _ (fun _ => g) x y` | 1 passed, 1 falsified, 0 inconclusive | 12.24 s |

The fold is an explicit rank-N argument, with provider discovery disabled.
Both exact implementations pass full-type independent replay, including their
behavior propositions, with six empty axiom inventories. This existing native
runner records its toolchain-qualified launcher; it does not separately pin the
resolved kernel executable. The lifecycle runner's stronger pin is a separate
validation boundary.

The positive request captures are complete: 63 requests for append and 14 for
length, no request timeouts, and exactly one empty-root acquisition each. Every
candidate type and positive/negative request uses backend 1/environment 3.
The two separate actual False controls each report 87 falsifications, zero
passed and zero inconclusive checks. Each retains 128 payload records and
omits 184 at the unchanged diagnostic row cap. Consequently both diagnostic
wrappers exit with an incomplete-capture result while their original behavioral
runners pass. No missing trace records are inferred or reconstructed.

These are observed run times, not a general performance guarantee. The native
acceptance covers Djinn on these workloads; the remaining engine/fold/tree and
accumulator cases retain their own acceptance requirements.

## Build and regression boundary

`cabal build exe:leant test:leant-synth-tests -j1 --ghc-options=-Werror` passes.
The complete unfiltered suite passes **686/686 in 335.32 seconds** (335.46
seconds for the owned process), with unchanged source, unit executable and
fake-Z3 identities. The existing cold-start boundary assertion was updated;
the new lifecycle behavior is exercised by the public sessions above.

The offline publication audit rehashes the source and captured artifacts and
binds trace summaries to their validated trace hashes. Previous diagnostic,
context and Church receipts keep their original revisions. This completes the
specific native-verification repair; broader supplied folds, contextual
providers, exact dictionary selection and Church behavior remain in the
[active re-triage](2026-09-07-synthesis-retriage.md).
