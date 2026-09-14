# Indexing composition after native kind adoption

The original integer-indexing query remains open, but its missing result can now
be investigated more precisely. Exference can synthesize function-valued Church
folds and the required integer-case step. The remaining question is how those
components compete and compose inside the original bounded search.

These diagnostics follow the [accepted native adoption](2026-09-14-native-kind-adoption.md).
They use the checked Djex executable and native dependency `e237e866`, with
source/runtime identities retained in each run. They add no original Church or
simultaneous-universe acceptance.

## Original Haskell indexing query

The unchanged public Exference query retains source `Int`, the supplied default,
original binder order, all 168 observations, window 256, budget 100,000, steps
100,000 and queue 8,192. Its synthesis process finishes in 41.11 seconds: all
256 checked candidates are falsified, with zero errors and zero timeouts. All
six independent oracle/primitive controls and the engine's actual-False control
pass. The positive cell remains failed.

The harness's positive-expectation assertion reports that no successful
behavioral observation was found; it does not mean a successful implementation
was displayed. The retained command diagnostics explicitly report no match and
the exhausted 256-candidate observation window.

This is a search miss even in the Haskell path, where all 256 observations finish.
The earlier native run's 23 falsifications and three request timeouts therefore
do not establish verification cost as the sole obstacle. The two paths have
different candidate construction and checking costs; their times are not a
controlled language-to-language speed comparison.

## Available components

A separate diagnostic retains the module, source type, provider inventory and
search limits, changing selection to `all` and the predicate to `True` to expose
the checked terms. The Exference request is constructed independently of this
presentation selection; final presentation may reorder the terms. All 256 terms
pass compiler checking. **82 definitions mention `PartialNumeric.partialIntCase`**,
and the inventory also contains function-valued folds, including:

```haskell
partial_exference_at a i2 f3 =
  f3 (\h -> \_ -> \_ -> h) (\_ -> a) i2
```

This example uses an `Int -> a` fold state and then applies it to the index. It
does not implement indexing. Other displayed examples combine the primitive
with a function-valued base, but no original behavior acceptance follows from
the `True` diagnostic.

The first inventory attempt omitted the original startup-isolation arguments
and emitted a missing-target error. It is marked invalid, with its originally
reported result preserved. The clean rerun uses `--ignore-startup` and the exact
empty environment, checks the original settings apart from `select = all`, and
validates the primitive inventory.

The isolated fold step has type:

```haskell
indexing_step :: forall a. a -> a -> (Int -> a) -> Int -> a
```

It succeeds on candidate 5, after four falsifications:

```haskell
indexing_step a b f3 i4 = PartialNumeric.partialIntCase i4 a b f3
```

Adding the outer index and Church-list bindings gives:

```haskell
indexing_step_in_context :: forall a.
  a -> Int -> (forall r. (a -> r -> r) -> r -> r) ->
  a -> (Int -> a) -> Int -> a

indexing_step_in_context a _ _ d f5 i6 =
  PartialNumeric.partialIntCase i6 a d f5
```

This succeeds on candidate 219, after 218 falsifications, at the same limits.
Both diagnostic predicates distinguish negative, zero and positive indices at
`Int` and `Bool` result types. Both exact displayed definitions also compile and
execute independently in GHC at their complete source signatures.

The larger-context result shows a substantial ordering effect in this diagnostic.
It is not a measurement of the internal ordinal of the step in the original
fold search: that search has its own partial term, usage history and pending
goals. Trace those states before changing penalties or pruning. The observations
do rule out simply treating the function carrier or integer-case step as an
unimplemented source construct.

## Verification measurement

The corrected shared-predicate experiment independently checks the exact original
168-observation predicate and eight rejections of a deliberately wrong default
implementation. Explicitly unfolding the shared predicate permits decidability
synthesis. Both variants compile in Lean with empty axiom inventories.

In this one ordered run, inline checking takes 4.506 seconds and shared checking
takes 1.551 seconds. This is an isolated elaboration measurement, not a production
cache or an end-to-end synthesis speedup. Any implementation proposal still needs
measurement of the actual command path, including setup, scope, environment
identity and the original shared deadline.

## Original simultaneous two-universe query

The original `two_box_selections` fixture is rerun through ordinary, named-`where`
and False queries in Djinn, Exference and Both, with the original window 60,
verify 12, steps 4,096, queue 1,024, budget off, Djinn depth-first, timeout 20 and
library/providers/classical off. Its independent reference replay passes.

All nine live cells remain unaccepted. Exference reaches the step limit with
18,974 queue prunes and proposes zero candidates; its False cell consequently
establishes no actual predicate rejection. Djinn and Both time out under the
original command limit. These are bounded misses, not non-inhabitation verdicts.

## Next implementation investigation

Trace the original `Int -> a` fold branch through step and base construction,
retaining its exact lexical identities, usage history, pending goals and search
cost. Locate the first point where the required integer-case application is
delayed or loses against other branches. Use the isolated and larger-context
steps as comparisons, without promoting their easier signatures to original
indexing acceptance. Keep the original simultaneous-universe query as the next
independent construction investigation.

The [diagnostic archive and index](../../test-church/receipts/indexing-composition-diagnostics-2026-09-14.json)
retain inputs, producing scripts, outputs, compiler checks, source/runtime hashes,
and failed attempts. Rebuildable executables and object/interface files are
omitted; their recorded hashes and build commands remain. Every archived member
was reopened and its digest verified. The [current plan](2026-09-14-synthesis-next-priorities.md)
keeps priorities 3 and 4 open.
