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
guard is 900 seconds. These are proposed limits pending live calibration, not
claimed acceptance. Owned process trees are terminated on timeout.

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

The implementation includes focused pure tests for source boundaries, verdict
classification, later-rendering acceptance, bounded traversal, accepted spelling
deduplication, and exact receipt ownership. The independent oracle baseline passed
all 33 named declaration/proof checks with empty axiom inventories; the Haskell
counterpart passed 17 assertions. This validates only the oracle witnesses and
wrong controls. **Live six-operation synthesis acceptance is pending.** Existing
rank-N and candidate-quality receipts do not establish behavioral-query acceptance.
