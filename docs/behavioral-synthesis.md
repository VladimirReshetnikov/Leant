# Behavioral assertions during synthesis

The named form supplies a Lean proposition about each proposed implementation:

```lean
:synth choose : ∀ A : Type, A → A → A where choose Nat 11 29 = 29
```

`choose` is a local name inside the assertion. It does not add or replace a
session declaration. Successful implementations are displayed and bound through
the usual `it1`, `it2`, … interface. The goal type should bind its type variables
explicitly, and other names in the assertion must resolve in the current Lean
context. Unknown names are rejected rather than introduced as auto-implicit
parameters.

The same form works with `synth-engine djinn`, `exference`, and `both`. The search
engines still generate inhabitants of the type. Leant checks every exact rendered
variant against that type, then checks the supplied proposition with that exact
term bound to the query name. Only a variant that passes both checks consumes a
displayed-success slot. If one rendering fails the assertion, the remaining
renderings of its already admitted candidate can still be tried.

## What a result establishes

Lean first parses both complete source terms, then checks that the predicate has
type `Prop` under a binder with the exact requested function type. This preflight
happens before search and does not change the interactive environment or proof
state. For each type-correct candidate, Leant asks Lean to kernel-check a proof of
the assertion using `by decide`:

* A checked positive proof means **passed**.
* If that attempt fails, a checked `by decide` proof of the negation means
  **falsified**.
* If neither proof succeeds, or a request times out or loses its backend, the
  check is **inconclusive**. Failure to prove an assertion is not a counterexample.

For example, `choose Nat 11 29 = 29` checks that application. It does not claim
that the implementation always returns its second argument. A conjunction of
examples establishes that conjunction. A proposition with an infinite universal
quantifier will generally not have an executable `Decidable` instance, so this
decision procedure can report inconclusive even when a mathematical proof exists.
All proofs are relative to the user's existing declarations and assumptions.

No `sorry`, native evaluation proof shortcut, or behavioral/Length certificate is
introduced. The accepted candidate keeps its own original engine metadata and
verification receipt. Matching text from a different occurrence cannot donate
typed provenance or Length authority.

## Bounds and failure reporting

The existing `synth-window`, `synth-verify`, `synth-shown`, engine step/choice
budgets, and provider scheduling still apply. Assertion failures do not refill a
raw candidate window or enlarge a search allowance. Accepted duplicate spellings
are skipped; a spelling whose check failed can be retried if it occurs again in
the admitted candidate groups. The command reports passed, falsified, and
inconclusive assertion counts separately from Lean type-check diagnostics.

The command first prepares the synthesis environment, using the same backend
setup and request-timeout boundaries as ordinary synthesis. Cold imports and
initial session reconstruction therefore do not spend the assertion allowance.
After successful preparation, it captures one `synth-timeout` deadline before
preflight and shares it through search lanes and assertion checks. Each
preflight, type check, or decision
request also has a five-second maximum, reduced by a smaller `backend-timeout`
setting and by the remaining command deadline. Requests require at least one
remaining second. Decision and preflight programs allow 200,000 Lean heartbeats.
These are operational limits, not language rank or function-arity restrictions.
Backend startup, session reconstruction, and existing translation/discovery
operations keep their established recovery behavior; after they complete, the
remaining deadline is rechecked before another behavioral request begins.
A timed-out request retires the backend through the existing protocol recovery
path, so an unfinished response cannot be reused by the next check.

This host-proposition form is separate from the existing leading Length syntax:

```lean
:synth --where List.length result = List.length arg0 -- List Nat → List Nat
```

That form retains its existing finite-spine contract, authorization, and receipt
rules. A natural Lean assertion neither activates nor bypasses those rules.

## Six-operation Church corpus

The shared specification in
[`behavior_spec.py`](../lib/Djex/test-church/behavior_spec.py) checks synthesized
`not`, `swap`, `map`, `append`, `reverse`, and `filter`. Live targets are rendered
directly from the existing manifest's expanded type trees, resolving `map`'s
source wildcard to `(a -> b)`. No source implementation enters synthesis.
Library search, provider discovery, and classical fallback are disabled, so the
computable oracle helpers cannot become named implementation providers.

| Operation | Finite observations per candidate | Discriminating inputs |
| --- | ---: | --- |
| `not` | 2 | Both Boolean inputs |
| `swap` | 15 | Nine integer pairs and six integer/Boolean pairs |
| `map` | 200 | Four integer transforms and a type-changing Boolean transform |
| `append` | 169 | All pairs of 13 lists, including unequal and empty inputs |
| `reverse` | 40 | Empty, ordered, repeated, and asymmetric lists |
| `filter` | 200 | Constant true/false, parity, negativity, and equality predicates |

Unary list tests enumerate all 40 lists of length at most three over `[-1,0,1]`;
append uses the 13 lists of length at most two. Encoders and decoders connect the
Church representations to native lists, Booleans, and products. These finite
oracles reuse the approach of the existing Haskell example tests, applied to
actual emitted candidates. They observe element values, order, and predicate
application, and require no source-typed Djinn graph.

The Lean counterparts put element types and eliminator result types in `Type 0`,
with the Church encodings themselves in `Type 1`. This is a universe-specialized,
predicatively valid counterpart of the Haskell signatures; it does not make Lean
`Type` impredicative. The 19 partial/default-bearing Church cases are outside this
total-operation corpus.

```powershell
python test-church/behavior_probe.py --prepare-only --spec-dir C:/Djex/test-church --output test-church/quality-results/behavior-prepared
python test-church/behavior_probe.py --leant PATH_TO_BUILT_LEANT_EXE --spec-dir C:/Djex/test-church --output test-church/quality-results/behavior
```

Run against an already built executable. Once the specification is vendored,
`--spec-dir` may be omitted. The default matrix explicitly includes **18 positive
queries**, six per Djinn, Exference, and Both, plus three false-predicate queries.
The Haskell runner adds 12 positive queries for a planned total of 30. `--engine`
and `--operation` select recorded subsets. The default `--window 256` sets both
`synth-window` and `synth-verify`; Djinn's raw proof cutoff also derives from this
window. Other initial settings are balanced ranking, shown 1, 100,000 Exference steps, 100,000 explicit Djinn choice
points, Djinn's ordinary `depth-first` strategy, and a 30-second shared synthesis timeout. The separate runner process
guard is 900 seconds. The Exference run below passed at these limits; complete
Djinn and Both corpus acceptance remains pending. Owned process trees are
terminated on timeout.

A larger frontier can be calibrated explicitly without changing the default:

```powershell
python test-church/behavior_probe.py --leant PATH_TO_BUILT_LEANT_EXE --spec-dir C:/Djex/test-church --window 4096 --djinn-strategy interleave --steps 100000 --budget 100000 --timeout 30 --output test-church/quality-results/behavior-window4096-interleave
```

This explicitly selects Djinn's `interleave` branch strategy and expands
candidate observation and verification allowances while retaining
shown 1, exact isolated kernel replay, empty-axiom checks, and false-predicate
controls. It does not increase the step/choice budgets or time guards. The runner
sends `:set synth-djinn-strategy`, requires its exact acknowledgment in transcript
order, and records the strategy in its receipt. It affects Djinn's work in both
Djinn and Both modes; `--djinn-strategy depth-first` retains the ordinary order.
Add
`--operation reverse --operation filter` for those two operations; repeat
`--operation` with any of `not`, `swap`, `map`, `append`, `reverse`, and `filter`
to select another subset. Omission selects all six. A pass at 4,096 is reported
at that bound and does not turn a previous 256-window miss into a pass.

Each preparation or live run requires a new output directory or an existing
empty one. A nonempty path is rejected before files are written, so use
different paths for `--prepare-only`, live runs, and successive calibrations.
The receipt preserves the configured window, engine/operation sets, and
unchanged acceptance checks alongside the retained process captures.

Every exact displayed term is replayed at its manifest-derived type in
its own `BehaviorCandidateN.lean` file, with a named theorem proving its finite
check returns true. Each replay contains only the observation prelude and that
candidate, so another replay candidate or a control cannot become an available
provider. Every candidate and theorem must have an empty axiom inventory. Six known
witnesses and ten exact-type wrong total controls establish that the oracles are
satisfiable and discriminating. They occur only in a separate `OracleControls.lean` replay, never in
the live transcript. A separate monomorphic swap control checks the pair
observation; the heterogeneous polymorphic swap type has no wrong total
parametric inhabitant, so this specialized check is not counted as one.

Receipts separate live synthesis, supplied-assertion counts, kernel replay, and
axiom inventories. They record source/manifest/specification hashes, executable
identity, exact commands and terms, interleaved settings, and process outcomes.
Missing output alone cannot pass a false-oracle control: actual falsification
must be reported. `--prepare-only` emits commands and `OracleControls.lean`
without running synthesis or the kernel.

## Validation status

Named behavioral queries check rendered groups as they arrive, one group at a
time. Exference retains its structural frontier ranking but does not wait for
the ordinary command's complete frontend quality pool before trying the
predicate. Each selected backend lane retains its original bounded trace: raw
candidates remain charged before rendering or duplicate rejection, and checking
a false predicate does not refill or restart that trace. Existing
strict/unused-binder, pattern, provider, and library fallback policies remain
separate bounded lanes. The existing candidate window, verification allowance,
displayed-success quota, and command deadline still
apply. Several accepted groups accumulate in encounter order with their own
verification receipts. Both mode retains its reserved engine order and each
group's own semantic authority; it does not inspect a later opposite-engine
candidate to borrow typed metadata. Progress notes describe only observed work.
Ordinary unnamed synthesis retains its existing finite-pool selection policy.

**Exference passed all six live operations** at balanced ranking, window and
verification allowance 256, shown 1, 100,000 search steps, and a 30-second command
deadline. Each exact displayed implementation and its finite-oracle theorem were
replayed independently. The six candidate files and separate oracle-control file
produced **45 checked declarations/proofs, all with empty axiom inventories**:
12 candidate/theorem inventories plus 33 control inventories. Before their first
success, `not`, `append`, `reverse`, and `filter` recorded respectively 2, 1, 21,
and 8 falsified assertions; none of the six positive queries reported an
inconclusive assertion check.

The mandatory `Nat → Nat where False` control displayed no implementation and
recorded **128 actual falsifications and zero inconclusive checks** before its
30-second command deadline. It is a successful rejection control, not a claim
that search exhausted or the underlying type is uninhabited. The complete live
process, including setup and this control, took 110.44 seconds; isolated kernel
replays followed separately. The [tracked compact acceptance receipt](../test-church/receipts/behavior-exference-streaming-first.json)
records the stable executable SHA-256
`18ce4695bcc0432ba31295622361d24eefdfc6d35ed245d9c4a5f9b934e4e863`
and the full local source-receipt SHA-256
`77e950604ac4fd7cbabb6d5dcae88c8e6311633639cbad4f8699d93581f26165`.
It retains exact terms, types, settings, per-query verdicts, replay-source and
capture hashes, axiom inventories, and the scope of each claim without copying
the large generated oracle programs or command transcript.

Separate [live quota regressions recorded in that receipt](../test-church/receipts/behavior-exference-streaming-first.json)
produced two distinct accepted results in both Exference and Both, demonstrated
that verification allowance 1 stops after one falsified projection while
allowance 16 reaches the accepted alternative, and verified a subsequent
recovery query. The latest serialized focused run passed ten tests in 0.29
seconds: seven streaming tests, including poisoned tails,
raw-slot charging, deferred opposite-engine preparation, and capped final
presentation across actual assessed batches, plus three corrected ordinary-route
source checks. These checks establish streaming
and quota behavior; they do not substitute for the six-operation corpus.

The complete Leant Haskell unit suite subsequently passed **600/600 tests**
serially (`-j1`), reporting 376.32 seconds (376.47 seconds for the process).
The layered-provider regression passed in 90.97 seconds overall with its original
30-second limits on each named staged search unchanged. The compact receipt
retains the aggregate capture and executable/source hashes. This establishes the
unit-suite milestone separately from the live behavioral corpus.

A separate live timeout diagnostic requested two results for `∀ A : Type, A → A`
after warming the backend. At window/verification allowance 256, **1,000,000
steps and a 10-second deadline**, it accepted one identity implementation and
then reported “accepted results retained; further search incomplete.” The
subsequent query succeeded with a 20-second deadline. The process completed in
54.13 seconds without reaching its 180-second outer guard. The compact receipt
records the exact terms, settings, message, captures, and executable
`4664a6d8baa5dda6d08a1ea94a6ec0b54da1b522951ab3e9cecc4e48a66907c1`.
This deliberately larger step setting belongs only to the timeout diagnostic;
the six-operation result above remains at 100,000 steps. An earlier two-second
attempt stopped in preflight and is not counted as partial-success coverage.

**Complete Djinn and Both six-operation corpus acceptance is still pending.**
The separate oracle baseline passed all 33 Lean declaration/proof checks and
17 Haskell assertions; those results validate the known witnesses and wrong
controls only. Existing rank-N and candidate-quality receipts do not establish
behavioral-query acceptance.
