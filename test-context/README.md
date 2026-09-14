# Lexical-Given synthesis acceptance

## Session provider identity

`run_session_provider_names.py` checks discovery through six public sessions:
nested namespaces, qualified names, attributes/comments, duplicate short names,
append/undo, and a rejected declaration. Nine literal-False queries force
rejection so that structural success cannot hide an incorrect provider inventory.
The small verification prefix deliberately reaches discovery; this is an
inventory/cache test, not acceptance of Church integer indexing.

```powershell
$leantExe = (cabal list-bin leant:exe:leant).Trim()
python -X utf8 -B test-context/run_session_provider_names.py --leant $leantExe --backend $backendExe --lake $lakeExe --output dist-newstyle/session-provider-names/run-1
```

Supply the actual Lean REPL and Lake executable paths. The fresh output directory
retains command inputs, transcripts, source snapshots, runtime hashes and exact
provider inventories. See the [repair and indexing diagnosis](../docs/reports/2026-09-14-session-provider-identity.md)
for the original baseline and remaining scheduling obligation.

## Polymorphic selection through dictionary application

`run_dictionary_selection.py` checks a local qualified consumer selecting a
supplied forall, directly and inside a nominal wrapper. Its result parameter
is rigid; observations distinguish both the dictionary and the supplied payload.
Each of the two cases has ordinary, named-`where` and actual-False queries in
Djinn, Exference and Both, for 18 cells. Positive outputs replay exactly at their
complete types with empty axiom inventories. Reference solutions are confined
to independent oracle processes.

```powershell
$leantExe = (cabal list-bin leant:exe:leant).Trim()
python -X utf8 -B test-context/run_dictionary_selection.py --leant $leantExe --output dist-newstyle/dictionary-selection/run-1
```

The gate retains 4,096 steps, a 60-candidate window, a 1,024-entry queue, a
20-second synthesis timeout and a separate 120-second process guard. `--case`
and `--engine` select diagnostic subsets; every output directory must be fresh.

## Selected polymorphic types and nominal universes

`run_polymorphic_selection.py` checks exact nominal universe selections and
selected polymorphic payloads through ordinary, named-`where` and actual-False
queries in Djinn, Exference and Both. Positive results retain their own typed
graph and rendered term, then replay independently against the original complete
signature. The reference implementations never enter synthesis sessions.

After building the executable, run the six nominal/polymorphic families and the
two chained/qualified-payload families separately:

```powershell
$leantExe = (cabal list-bin leant:exe:leant).Trim()
python -X utf8 -B test-context/run_polymorphic_selection.py --leant $leantExe --output dist-newstyle/selected-polytypes/core --case fixed_higher_box --case selected_higher_box --case boxed_polymorphic_payload --case boxed_type_one_quantifier --case boxed_named_quantifier --case boxed_strict_quantifier
python -X utf8 -B test-context/run_polymorphic_selection.py --leant $leantExe --output dist-newstyle/selected-polytypes/chained --case polymorphic_first_of_two_selections --case boxed_qualified_polymorphic_payload
```

These select 54 and 18 cells respectively. `--engine` narrows a diagnostic run;
every output directory must be new or empty. The controller retains a
60-candidate window, 4,096 steps, a 1,024-entry queue, a 20-second synthesis timeout
and a separate 120-second process guard.

The unfiltered controller also includes `two_box_selections`, the unresolved
query constructing two nominal universe selections in one result. Do not treat
the unfiltered invocation as an all-green gate, or a passing subset as closure of
that diagnostic. The [current priorities](../docs/reports/2026-09-14-synthesis-next-priorities.md)
distinguish these obligations and record the acceptance evidence.

## Public production route

`run_production.py` exercises ordinary and named-`where` contextual synthesis
through the live executable in Djinn, Exference, and Both. Its fixed 27-cell
matrix covers local identity, constrained rank-N forwarding and forced local
Given application, three actual False controls, and six selected-class-universe
refusals. Search receives only the declared class and nominal datatype;
reference implementations remain in independent oracle processes.

The [historical production receipt](receipts/ordinary-context-streaming.json)
records **39/39 passing cells** at its earlier implementation, with all eighteen exactly displayed candidates
independently checked at their complete Lean types. Their replay contains 72
finite payload observations and 144 empty axiom inventories. Candidate receipts
retain the displayed variant's own graph, renderer and engine. Source,
executable, resolved kernel, command and replay-input identities stayed unchanged.
That historical strict build and **680-test** serial suite passed. Its blanket
higher-universe and provider refusals are no longer current expectations: higher
universes have their own acceptance runner, and provider behavior depends on
the engine and available source metadata. Those twelve obsolete refusal cells
have left this lexical-only gate; the remaining selected-class-universe refusal
uses the current diagnostic. The original failed 39-cell rerun is retained in
the dictionary-integration evidence rather than relabeled as a pass.

Run from the repository root after the strict build:

```powershell
python -B -m unittest discover -s test-context -p test_production.py
python -B test-context/run_production.py --output dist-newstyle/context-production/run-1
```

`--leant` and `--lean-runtime` override the Windows executable defaults.
The output directory must be new or empty. The default acceptance gate keeps a
32-candidate/verification window, 20,000 search steps/choices, a 45-second query
deadline and a separate 120-second process guard. Contextual ordinary queries
verify bounded groups incrementally and present the assessed stream prefix;
they do not rank an unobserved whole candidate pool.

That receipt accepts local `Type 0` contexts with complete source metadata.
The [global-method runner](global-methods/README.md) adds actual projection
discovery, complete provider source packets and exact cache/verification
correlation. Its [implementation report](../docs/reports/2026-09-08-global-contextual-providers.md)
records the new integration gates and repeat local-context results. Unsupported
provider packets, richer universe metadata and selection between equal active
dictionaries remain separate implementation gates. An explicit refusal
counts only for its designated unsupported case, never for a positive query.
The [re-triage report](../docs/reports/2026-09-07-synthesis-retriage.md)
records the remaining scope and preserved historical failures.

`run_serializer.py` separately compiles the exact production synthesis prelude
emitted by the built unit executable. That component check establishes serializer
validity; the production matrix establishes public command acceptance.

## Contextual constructors

`run_constructors.py` is the new acceptance driver for exact universe-zero
constructor metadata and its composition with lexical dictionaries. The full
matrix has 21 positives and six actual `where False` controls across Djinn,
Exference and Both. It covers method-selected and argument-only singletons,
preserved tails, an `Option` wrapper, nested lists and nested dictionary scopes.
Methods are discovered live with cap 1; argument-only cases disable discovery.

```powershell
python -X utf8 -B test-context/run_constructors.py --leant <built-leant.exe> --output dist-newstyle/contextual-constructors/run-1
```

The driver retains a 32-candidate/verification window, 20,000 steps/choices and
45-second command deadline. It checks exact source graph ownership and replays
each displayed implementation at its original type and observations in an
independent kernel process with empty axiom inventories. Reference implementations
never enter search sessions. Source, input and runtime hashes must remain fixed.
`--engine` and `--operation` select diagnostics; a selected subset cannot establish
acceptance of the full matrix. A process exit without the required positive or
actual predicate rejection is a failed case. Each failed case is retained while
the driver continues through the remaining selected cases. The
[complete diagnostic](../docs/reports/2026-09-13-contextual-constructor-frontier.md)
records the historical 17/21 positive replays and 6/6 False controls. The later
[constructor release](../docs/reports/2026-09-13-contextual-constructor-use-acceptance.md)
closes all 21 positives; the strict-implicit release repeats the complete matrix
successfully. The earlier plan-ordering experiment was reverted after its run.

## Strict-implicit contextual binders

`run_strict_implicit.py` reuses the method, argument and nested-context observations
with strict-implicit type binders. Its nine exact positive replays and six actual
False controls pass across Djinn, Exference and Both, at the original constructor
bounds. It additionally checks the displayed strict binder introductions. See the
[release report](../docs/reports/2026-09-13-strict-implicit-source-acceptance.md)
and [receipt](receipts/strict-implicit-source-2026-09-13.json).

```powershell
python -X utf8 -B test-context/run_strict_implicit.py --leant <built-leant.exe> --output dist-newstyle/strict-implicit/run-1
```

## Direct renderer component

`run_replay.py` exercises the isolated `Leant.Synth.ContextRender` module using
sealed graph fixtures. It runs all 21 focused tests, emits actual rendered Lean
terms from the test executable, and checks those terms against seven independently
written complete signatures in a separate Lean 4.32.0 process.

The fixtures distinguish equal-predicate dictionary slots, an outer dictionary
under a matching inner binder, a rank-N constrained callback, nested type and
context introductions, a constrained global provider, and a local let. Dictionary
payloads 11, 29, and 43 make the selected evidence observable. Seven positive
observations and two wrong-result controls must pass. All sixteen implementation
and proof axiom inventories must be present and empty.

Run after the strict Haskell build:

```powershell
cabal build leant:exe:leant leant:test:leant-synth-tests --ghc-options=-Werror -j1
python -B test-context/run_replay.py --output dist-newstyle/context-acceptance/replay-1
```

The output directory must be new or empty. The runner owns each child process
tree with a 120-second guard, records raw stdout/stderr, retains the exact source
snapshot and replay file, and rejects source or executable changes during the
run. A successful receipt establishes this component's behavior; it does not
establish live synthesis reachability, production source-metadata preparation,
instance/superclass derivation, or routing through the ordinary `:synth` command.

The first integration replay caught Lean implicitly introducing a residual
dictionary around a compound application. Making the compound term explicit
with `@(let ...)` preserves its checked partial-application type. Both formerly
failing cases now pass the full independent replay. The retained successful
receipt is [renderer-replay.json](receipts/renderer-replay.json).

## Auxiliary provider discovery

`run_provider_inventory.py` compiles the current production discovery generator,
emits its actual Lean programs, executes them with a separate Lean kernel, and
parses each resulting inventory with the production Haskell parser. Four cells
cover ordinary and contextual source modes through namespace roots and explicit
session declarations. Each must retain exactly a generic fold, two constructors,
and an ordinary user function named `elim`, while excluding both generated
constructor eliminators. The explicit-session cases also name those generated
helpers, so a session declaration cannot bypass the semantic exclusion.

```powershell
python -B test-context/run_provider_inventory.py --output dist-newstyle/provider-inventory-check
```

The selected Cabal project and vendored Djex library must already be built. This
is a real-kernel provider-discovery regression, separate from candidate synthesis
and the complete native unit suite. The runner retains emitted source, exact
inventories, process captures and source/kernel hashes; use a fresh output
directory. See the [implementation report](../docs/reports/2026-09-08-semantic-auxiliary-providers.md)
for public tree-query validation and remaining behavioral failures.
