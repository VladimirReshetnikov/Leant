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
state. For each type-correct candidate, Leant asks Lean to kernel-check proofs in
this order: the assertion by `decide`, its negation by `decide`, the assertion by
bounded `simp`, then its negation by bounded `simp`. Each attempt uses the same
complete candidate, requested type, and lexical assertion:

* A checked positive proof means **passed**.
* A checked proof of the negation means **falsified**.
* If no proof succeeds, or a request times out or loses its backend, the
  check is **inconclusive**. Failure to prove an assertion is not a counterexample.

For example, `choose Nat 11 29 = 29` checks that application. It does not claim
that the implementation always returns its second argument. A conjunction of
examples establishes that conjunction. A proposition with an infinite universal
quantifier will generally not have an executable `Decidable` instance. Bounded
simplification can close some such propositions; for example, an identity
implementation can satisfy `∀ n : Nat, f Nat n + 0 = n`. Simplification must
close the whole goal. Partial simplification remains inconclusive, as does a
proposition requiring a proof beyond these methods.
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

Named behavioral queries let Exference propose implementations that ignore
inputs or constructor fields. Finding some type-correct candidates that later
fail the assertion cannot suppress that part of the search. Ordinary synthesis
retains its established preference and fallback policy.

For behavioral queries, `both` alternates observed engine slots, starting with
Djinn. Rendering misses and duplicates also yield the next turn; each remains
charged against its source window. The requested number of successes and the
verification quota do not change this schedule. Each retained candidate keeps
its own source authority, and a success leaves unobserved continuations alone.
This is fairness between exposed stream slots, not preemption of an engine
while it computes its next slot; the shared command deadline still applies.

The command first prepares the synthesis environment, using the same backend
setup and request-timeout boundaries as ordinary synthesis. Cold imports and
initial session reconstruction therefore do not spend the assertion allowance.
After successful preparation, it captures one `synth-timeout` deadline before
preflight and shares it through search lanes and assertion checks. Each
preflight, type check, or proof
request also has a five-second maximum, reduced by a smaller `backend-timeout`
setting and by the remaining command deadline. Requests require at least one
remaining second. Proof and preflight programs allow 200,000 Lean heartbeats.
Simplification additionally permits at most 10,000 steps. All four proof
attempts share the command deadline; an interrupted backend ends the sequence.
These are operational limits, not language rank or function-arity restrictions.
Backend startup, session reconstruction, and existing translation/discovery
operations keep their established recovery behavior; after they complete, the
remaining deadline is rechecked before another behavioral request begins.
A timed-out request retires the backend through the existing protocol recovery
path, so an unfinished response cannot be reused by the next check.

The [simplification acceptance runner](../test-behavioral/README.md) distinguishes
completed quantified proofs, proved negations, opaque propositions, and partial
simplification. It checks exact displayed terms independently and records the
actual axiom inventories. Simplification proofs can use Lean's `propext` and
`Quot.sound`; this does not change the candidate's own axiom inventory or imply
that an arbitrary supplied assertion is axiom-free.

This host-proposition form is separate from the existing leading Length syntax:

```lean
:synth --where List.length result = List.length arg0 -- List Nat → List Nat
```

That form retains its existing finite-spine contract, authorization, and receipt
rules. A natural Lean assertion neither activates nor bypasses those rules.

## Djinn search alternatives

Explicit `synth-djinn-strategy interleave` enables bounded exploration of useful
term alternatives beyond Djinn's historical inhabitation search. For a checked
plan over atomic and function types, the first LJT proof is preserved. After
that proof, a reusable beta-normal term search can explore compositions and
repeated uses of local functions. It also admits function-valued variables and
partial applications, so passing a function does not require expanding it into
extra lambdas. This addresses higher-order folds such as Church `reverse` and
`filter` without introducing operation names or reference implementations into
search. The ordinary `depth-first` strategy remains the default.

The additional search uses exact type identities, increasing head-use sizes,
and an index of type-compatible applications. A conservative analysis stops a
size ladder only when it establishes a finite maximum; an unresolved cycle does
not justify discarding larger terms. Resumable plan and proof streams share the
configured choice and raw-proof allowances, rotating after a proof or a bounded
work quantum. Rejected proofs and normalized duplicates still consume their
raw slots. Preserving a plan's first proof does not promise an unchanged first
result across differently scheduled plans.

Common-result contexts give related instantiations a smaller search context.
They group existing checked premises by their exact terminal result formula;
each member retains its own source association and visible type-argument vector.
The grouping does not assert equality of the complete assignment vectors. These
contexts provide positive candidates only, and a candidate must use a member of
the selected group. Failure in such a context cannot establish noninhabitation.
Every resulting proof still passes the original plan's proof and scope checks
before conversion, followed by Lean's exact type and behavioral checks.

Named Djinn queries give historical plans, exact-result specializations, and
other carrier plans separate FIFO turns. Each turn ends after a raw proof or
64 charged choices; adding plans in one family cannot dilute another family's
turn frequency. Focused carrier plans ending at the demanded result give the
increasing-size normal-form branch a larger finite turn. A singleton bridge
also stays available when several quantified inputs can reuse the same exact
specialization. The original batch schedule remains in place for unnamed
queries. The [streaming implementation report](../lib/Djex/docs/reports/2026-09-06-djinn-behavioral-streaming.md)
records the scheduling rules and acceptance evidence.

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
The Haskell runner adds 12 positive queries for a cross-language total of 30. `--engine`
and `--operation` select recorded subsets. The default `--window 256` sets both
`synth-window` and `synth-verify`; Djinn's raw proof cutoff also derives from this
window. Other initial settings are balanced ranking, shown 1, 100,000 Exference
steps, 100,000 explicit Djinn choice points, Djinn's ordinary `depth-first`
strategy, and a 30-second shared synthesis timeout. The separate runner process
guard is 900 seconds. Calibration settings and acceptance are recorded per
engine; the default profile does not describe every accepted run. Owned process
trees are terminated on timeout.

A larger frontier can be calibrated explicitly without changing the default:

```powershell
python test-church/behavior_probe.py --leant PATH_TO_BUILT_LEANT_EXE --engine djinn --window 65536 --djinn-strategy interleave --steps 100000 --budget 500000 --timeout 120 --process-timeout 1500 --output test-church/quality-results/behavior-djinn-final
```

This explicitly selects Djinn's `interleave` branch strategy and expands
candidate observation and verification allowances while retaining
shown 1, exact isolated kernel replay, empty-axiom checks, and false-predicate
controls. This Djinn profile explicitly uses 500,000 choices and a 120-second
command deadline. Its 1,500-second process guard also covers cold preparation
and all seven commands in the live session; each standalone kernel replay has
its own process guard. These are separate from the command's search allowance.
The runner sends `:set synth-djinn-strategy`, requires its exact acknowledgment in transcript
order, and records the strategy in its receipt. It affects Djinn's work in both
Djinn and Both modes; `--djinn-strategy depth-first` retains the ordinary order.
Add
`--operation reverse --operation filter` for those two operations; repeat
`--operation` with any of `not`, `swap`, `map`, `append`, `reverse`, and `filter`
to select another subset. Omission selects all six. A pass at 65,536 is reported
at that bound and does not turn a previous smaller-window miss into a pass.

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

Named behavioral queries check rendered groups one group at a time. Exference
retains its structural frontier ranking but does not wait for the ordinary
command's complete frontend quality pool before trying the predicate. Djinn
also yields checked typed candidates incrementally, preserving each one's own
source graph and rendering authority. Both mode defers unused engine work,
including each Djinn continuation. Once the displayed-success quota is met,
neither backend's unobserved tail is forced. Each selected backend lane retains its
bounded trace: raw
candidates remain charged before rendering or duplicate rejection, and checking
a false predicate does not refill or restart that trace. Existing
strict/unused-binder, pattern, provider, and library fallback policies remain
separate bounded lanes. The existing candidate window, verification allowance,
displayed-success quota, and command deadline still
apply. Several accepted groups accumulate in encounter order with their own
verification receipts. Both mode retains its reserved engine order and each
group's own semantic authority; it does not inspect a later opposite-engine
candidate to borrow typed metadata. Progress notes describe only observed work.
Djinn's named-query stream uses deterministic discovery order, so its first
accepted result can differ from earlier complete-pool ranking. Ordinary
unnamed synthesis retains its existing finite-pool selection policy. Search
errors and completion evidence are reported only when their observation is
reached; a passing prefix is not a claim that the search finished.

### Current Djinn streaming acceptance

The final streaming executable, SHA-256
`9a55eb231c5dd6608eb6750e87a5f05e2dad76cae98e20be197d2e9cf5d94424`,
passed all 18 Lean behavioral cells at unchanged per-engine limits. Each of
Djinn, Exference, and Both passed six operations, 626 finite observations, an
actual false-predicate control, and independent exact-term kernel replay with
45 empty axiom inventories. All accepted spellings matched the frozen baseline.
The strict build and all 615 Leant tests passed with canonical Djex source
revision `6a964389`; later documentation-only vendor updates retain that tested
implementation.

Separate live controls passed ten quota/inconclusive queries and both
ten-second deadline-retention cases. Djinn retained 75 accepted results below
quota 256; Both retained one below quota two. Both sessions then recovered.
Including warmup and recovery, the three control runs independently replayed
89 retained candidate occurrences with 180 empty axiom inventories. The opaque
assertion control established semantic inconclusiveness through separate
preflight and positive/negative decision attempts. Both-mode acceptance does
not assert that both constituent engines independently reached every outcome.

The [paired compact receipt](../lib/Djex/test-church/receipts/behavior-streaming-final.json)
pins the five Haskell/Lean profiles, build/source associations, full affected
unit suites, and live controls. The
[implementation and measurement report](../lib/Djex/docs/reports/2026-09-06-djinn-behavioral-streaming.md)
explains the initial deadline regression and repair. Djinn's median
query-to-result visibility improved from 30.752 to 7.497 seconds, but its first
cold result remained near 94 seconds from process entry. Exference and Both
had higher medians in these single-run controls; no general cross-engine
speedup is claimed.

### Earlier source-evidence six-operation acceptance

The executable with SHA-256
`baa4fb4ce1cc27f49900f0ded27f4b64468d00b29b57bbc3bc2e204ef1ff408a`,
using vendored Djex revision `22da13fd`, passed **all 18 Lean behavioral cells**:
all six operations independently under Djinn, Exference, and Both. Each batch
used balanced ranking and shown 1, with library search, provider discovery,
and classical fallback disabled. The accepted bounds differ by engine:

| Engine | Djinn strategy | Window / verification | Djinn choices | Exference steps | Command deadline | Process guard |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Djinn | `interleave` | 65,536 | 500,000 | unused | 120 s | 1,500 s |
| Exference | `depth-first` (unused) | 256 | unused | 100,000 | 30 s | 900 s |
| Both | `interleave` | 256 | 100,000 | 100,000 | 30 s | 900 s |

Each displayed term and its finite-oracle theorem passed independent Lean
kernel replay. Each batch produced **45 empty axiom inventories**: 12 from its
six candidates and their theorems, plus 33 from the separate control file. Across
the three batches this is 36 candidate/theorem inventories and the same 33
controls replayed three times, for 135 empty-inventory observations, not 135
distinct declarations. The six operations exercise 626 finite observations per
engine. All 18 positive queries reported zero inconclusive checks.

| Operation | Djinn falsifications before success | Exference / Both falsifications before success |
| --- | ---: | ---: |
| `not` | 5 | 2 |
| `swap` | 0 | 0 |
| `map` | 6 | 0 |
| `append` | 181 | 1 |
| `reverse` | 51 | 21 |
| `filter` | 61 | 8 |

The mandatory `Nat → Nat where False` queries displayed no terms and recorded
five actual falsifications in Djinn and 128 each in Exference and Both, with
zero inconclusive checks. The latter two reached their 30-second command
deadlines after actual falsifications; this does not claim exhaustive rejection
or uninhabitability. The live processes completed in 196.27 seconds for Djinn,
43.25 seconds for Exference, and 43.99 seconds for Both. Seven isolated kernel
processes followed each live batch separately. These timings describe the
different accepted profiles, not a comparative performance claim.

The [combined compact receipt](../test-church/receipts/behavior-lean-complete.json)
indexes the separate [Djinn](../test-church/receipts/behavior-djinn-final.json),
[Exference](../test-church/receipts/behavior-exference-final.json), and
[Both](../test-church/receipts/behavior-both-final.json) receipts. They retain all
exact terms, types, commands, verdicts, source and capture hashes, and isolated
replay inventories. Offline extraction reconstructed the commands and replay
sources and reparsed the captures before accepting the compact projections; it
was not another live or kernel run. These new Lean receipts do not repeat the
earlier streaming or quota claims below.

### Earlier unit and cross-language closure

The fresh complete Leant unit suite passed **600/600 tests** serially (`-j1`)
in 308.18 seconds, with process exit 0 after 308.41 seconds. The
[final validation receipt](../test-church/receipts/behavior-validation-final.json)
retains the test executable, source pins, and capture hashes from
`dist-newstyle/behavioral-acceptance/leant-unit-common-full-final`.
This is a new aggregate run on the current sources, separate from the earlier
376.32-second unit milestone below and from live synthesis or kernel replay.

The [canonical Haskell behavioral guide](https://github.com/VladimirReshetnikov/Djex/blob/main/docs/behavioral-synthesis.md)
records the other **12 behavioral cells**, all six operations under each Haskell
engine on executable
`d5d9f0112f300b4d33c0fbebdcf39a9d3aaf22db5b054c6411882c0c6651cefd`.
Haskell Djinn used explicit Interleave, a 65,536 window, and 500,000 shared
choices; Haskell Exference used a 256 window and 100,000 steps. Both used
balanced ranking and first-result selection. The exact accepted definitions
were independently compiled at their full original types and checked against
the finite conditions. Together with the 18 Lean cells above, these receipts
close the **30-cell behavioral corpus** at the recorded per-engine limits.
Haskell execution evidence and Lean kernel evidence remain distinct; neither
establishes universal behavioral equivalence or completeness of bounded search.

### Earlier Exference and streaming milestone

**The earlier Exference executable passed all six live operations** at balanced ranking, window and
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

The separate oracle baseline passed all 33 Lean declaration/proof checks and
17 Haskell assertions; those results validate the known witnesses and wrong
controls only. Existing rank-N and candidate-quality receipts do not establish
behavioral-query acceptance.
