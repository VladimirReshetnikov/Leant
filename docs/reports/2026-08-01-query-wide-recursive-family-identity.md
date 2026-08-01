# Query-wide recursive family identity

**Date:** 2026-08-01

**Scope:** Leant's exact-head `FParamRec` projection for rank-N and
impredicative synthesis

**Implementation:** `03e591f` (engine, renderer, and focused tests) and
`e890eeb` (Lean 4.31 golden transcript)

## Outcome

Leant now gives differently instantiated proper-type occurrences of one
recursive Lean inductive a query-wide engine identity. Both Djinn and
Exference can synthesize direct rank-N transport such as:

```lean
((∀ a : Type 1, Demo.RecBox a) →
  Demo.RecBox (∀ b : Type, b → b))
```

as:

```lean
fun x => x _
```

The result is deliberately about family identity rather than recursive program
synthesis. Follow-up commit `e01b270` gives both engines one validated native
recursive datatype declaration when the query supplies a complete, compatible
schema. Djinn uses Djex's bounded positive constructor projection—one layer per
SCC, with at most two independent SCCs on a logical path—while Exference may
inspect one constructor layer. Partial and otherwise unsafe plans retain the
abstract-family constructor-premise fallback. No path invents a recursive
definition, induction, or unbounded deconstruction.

## Fragment boundary

For a qualifying recursive, non-indexed, non-mutual inductive whose applied
arguments are all proper types, the Lean serializer emits:

```text
FParamRec complete exactHead displayKey parameters constructors
```

The fields have distinct jobs:

- `complete` says whether Lean serialized the complete constructor inventory;
- `exactHead` is the fully qualified family identity shared across
  occurrences;
- `displayKey` identifies this specialized occurrence and is also the spelling
  used by blocked recursive self fields;
- `parameters` preserves the ordered proper-type arguments, including a
  supplied polytype; and
- `constructors` is the occurrence-specialized field inventory used for
  planning, introduction, and rendering.

Indexed families, dependent constructor fields, term parameters, and other
unsupported recursive shapes retain their established opaque or
occurrence-local boundaries. This change does not widen recursive admission in
the Lean serializer; it gives already admitted `FParamRec` values a safe shared
identity.

## Query-wide planning

Planning begins before fragment lowering and groups uses by exact Lean head.
Its roots are:

- the synthesis goal;
- caller premises; and
- every live provider that survived depth admission.

One head must have one parameter arity. Conflicting arities are rejected
rather than abstracted or conflated. A nominal occurrence of the same head, a
mixture with a non-recursive schema, or an unsafe recursive schema makes the
head abstract query-wide.

A recursive structural template is selected only when:

1. one complete occurrence supplies pairwise-distinct plain type variables as
   its parameters;
2. replacing those parameter fragments with private formals produces a closed
   generic constructor schema;
3. the generic schema specializes back to every recursive occurrence;
4. every such occurrence is complete; and
5. all validating template candidates are equivalent.

The template source must use distinct plain variables, but the other validated
occurrences may use structured or repeated proper types. This is what permits
a source such as `List a` to establish the schema used by
`List (∀ b, b → b)`. If a query contains only structured or repeated
occurrences and no recoverable generic source, it conservatively uses the
abstract plan. That is the initial implementation contract recorded by this
report; the positive-only structured-source successor is described below.

The decision matrix is:

| Query-wide evidence for one recursive head | Djinn | Exference |
| --- | --- | --- |
| Unique complete compatible schema | Shared parameterized recursive data; bounded positive introduction | Shared parameterized recursive data; one-layer elimination |
| Structured/repeated use validated by a generic occurrence | Same shared recursive data | Same shared recursive data |
| Partial inventory | Abstract exact family + occurrence constructor premises | Abstract exact family + occurrence constructor premises |
| No recoverable template | Abstract exact family + occurrence constructor premises | Abstract exact family + occurrence constructor premises |
| Incompatible schemas | Abstract exact family + occurrence constructor premises | Abstract exact family + occurrence constructor premises |
| Recursive/nominal or recursive/finite collision | Abstract exact family + occurrence constructor premises | Abstract exact family + occurrence constructor premises |
| Inconsistent arity | Translation error/refusal | Translation error/refusal |

Constructor premises are registered only where that engine lane consumes them;
provider inventories remain providers rather than silently adding global
constructor axioms. Every fallback nevertheless preserves the one exact
family application, so positive transport remains available even when
elimination is withheld.

## Recursive-knot normalization

Lean serializes a blocked self field as an atom keyed by its specialized
display spelling. For example, the two schemas for `List a` and `List b` may
contain the unrelated-looking atoms `"List a"` and `"List b"`. Comparing those
inventories literally would reject one real recursive family.

Before genericization, Leant replaces the occurrence's blocked self atom with
a private sentinel application of the exact family head to that occurrence's
parameter vector. Parameter substitution can then turn both schemas into the
same generic knot:

```text
List formal
```

The sentinel is ignored as a separate nominal occurrence during planning. It
therefore describes the recursive knot without creating a structural/nominal
collision. Schema comparison is based on the exact head and applied
parameters, not display keys or constructor namespaces.

Distinct exact heads remain distinct even when crafted fragments reuse both a
display key and constructor spellings. This prevents accidental transport
between nominally unrelated recursive families.

## Reachability-aware fixed point

Nested constructor inventories are metadata until a selected representation
will consume them. Scanning every nested inventory eagerly would let an unused
provider schema alter a family plan or rigidify a field that never reaches the
engine.

The planner therefore grows its use map monotonically to a fixed point:

1. collect exact-family uses from the goal, caller premises, provider types,
   and their parameter vectors;
2. choose a provisional plan for every reached exact head;
3. follow fields from selected structural data templates;
4. follow fields from recursive constructor premises that the active engine
   lowering will register; and
5. repeat until no new use is reached.

Neither engine follows occurrence constructor premises when it selected a
native recursive declaration, because the declaration template is the consumed
inventory. Abstract recursive fallbacks follow active introduction premises
instead. Provider occurrences do not acquire constructor premises.

The use set only grows. If newly reached evidence makes a provisional plan
abstract, already inspected fields remain in the scan as a conservative
over-approximation. This preserves order independence while ensuring that an
unused abstract outer-family inventory cannot poison an otherwise compatible
recursive plan.

## Lowering and fixed fields

For a selected native plan, Leant creates one parameterized
`DataTypeDeclaration` keyed by the exact Lean head in both engines. At each
occurrence it:

1. translates the actual proper-type arguments;
2. applies the shared private family constructor;
3. installs the display-key-to-occurrence mapping before translating any
   constructor field; and
4. lowers the selected generic constructor schema against that installed knot.

Installing the occurrence first is essential: a recursive field must resolve
to the applied shared datatype, not become a fresh atom because it appeared
earlier in traversal order.

Djex owns the engine asymmetry after that shared lowering. Djinn exposes only
its bounded positive constructor projection, whereas Exference may also inspect
one constructor layer.

Concrete constructor fields that are not family parameters must also remain
rigid. The query-wide pre-scan collects fixed opaque fields only from selected,
reachable structural schemas and creates private proper-type declarations for
them before lowering. It subtracts every normalized recursive self key from
that seed, so the self reference continues to resolve through the recursive
knot. The existing `Std.Format` regression verifies that a zero-parameter
recursive declaration with a `String` field stays closed and constructible.

For an abstract fallback in either engine, Leant declares one abstract
proper-kinded constructor for the exact head. Each active occurrence is the
application of that same head to its own translated parameters. Leant installs
that application before lowering occurrence constructor fields, then registers
the resulting constructor functions as introduction premises. This retains
sound construction without exposing a recursive eliminator.

## Occurrence-specific rendering

The shared recursive declaration stores generic constructor fields, but Lean
elaboration happens at one concrete result or scrutinee occurrence. Constructor
metadata therefore records the exact family head and private formals. When
fitting a constructor application or `match`, the renderer:

1. requires the actual `FParamRec` occurrence to have the same exact head;
2. prefers the complete fields serialized on that occurrence; and
3. uses capture-safe specialization of the generic fields only as a defensive
   fallback.

This preserves occurrence-local binder names and structured rank-N field
domains. A template supplied by a provider with renamed variables can safely
fit a constructor or pattern at the goal's impredicative occurrence.

## Search and verdict contract

The principal new inhabitant is direct guarded transport: a quantified family
value is instantiated at a polytype already supplied by the query. That works
under both engines because both now see one exact family constructor applied at
different arguments.

Exference's structural plan additionally retains its existing bounded
recursive case analysis. A recursive field exposed by the first match is an
ordinary branch-local value and is not eagerly split again. Providers such as
`List.map` remain available for recursive work through the normal provider
lane.

Recursive occurrences continue to poison Djinn negative evidence even when a
positive structural plan exists: their concrete recursive semantics are not a
complete logical decision procedure. Abstract family fallbacks also mark the
family projection incomplete when they hide serialized structure. Search
exhaustion is therefore reported only as a bounded no-term result, never as a
proof that a recursive Lean type is uninhabited. Exference never makes a
negative claim.

Every candidate from either engine is still rendered and re-elaborated by Lean
against the exact original goal. Shared identity changes discovery, not the
trusted boundary.

## Successor: impredicative one-layer field projection

The follow-up projection admits the useful eliminator that the initial strict
policy missed:

```lean
inductive Demo.Headed (a : Type 1) : Type 1 where
| mk : a → Demo.Headed a → Demo.Headed a

-- goal
Demo.Headed (∀ x : Type, x → x) → (∀ x : Type, x → x)
```

The intended candidate is finite:

```lean
fun h => match h with | .mk value _ => value
```

Exference opens exactly one constructor layer. The recursive tail becomes an
ordinary branch-local value and is deliberately ignored; it is never scheduled
for another automatic match. The change therefore adds field projection, not
recursion, induction, a fold, or an unbounded eliminator.

### Strict-first omission policy

Exference's established lane requires every introduced binder to be used.
That remains the first search, with its existing ordering and candidate prefix.
Only when it produces no renderable candidate group does Leant rerun the same
session and environment with unused inputs allowed. A successful strict lane
ends the pair unchanged; the relaxed lane is not appended as an alternative
enumeration and is not reached merely because a later Lean verification rejects
a strict spelling.

Both requests retain the configured `synth-steps` limit and the same bounded
queue. A complete miss may therefore spend two engine step budgets for one
Exference invocation. It does not receive two wall-clock allowances: the whole
`:synth` command remains beneath its single outer `LEANT_SYNTH_TIMEOUT`
deadline. This inner strict/relaxed pair is independent of the outer
provider-free/provider-enriched scheduling; if both outer passes are needed,
each Exference invocation follows the same rule within the one shared command
deadline.

Search and checking may retain a typed name for the ignored field. At the
stable output boundary, and idempotently again before Leant assigns Lean-facing
names, an unused pattern binding becomes a real wildcard. The rendered term
therefore says `.mk value _` rather than inventing a misleading tail name, and
Lean re-elaborates that exact wildcard term against the original goal.

### Structured parameters are positive approximations

The initial native-plan rule required a complete occurrence with distinct plain
type variables. The follow-up admits any pairwise-distinct proper-type parameter
vector, including a supplied polytype, as a possible template source. The
existing guards still require one exact head and arity, complete recursive
inventories, a closed capture-safe template, specialization back to every
observed occurrence, agreement among viable templates, and no nominal or
finite-family collision.

This widening is deliberately not a claim that the recovered schema is the
original Lean declaration. `FParamRec` carries occurrence-specialized
constructor fields, but it does not preserve declaration-level provenance for
each parameter occurrence. If a fixed constructor field happens to equal the
sole structured actual parameter, whole-fragment replacement cannot tell that
coincidence from a genuinely generic field. Multiple occurrences often
disambiguate the template, but an unseen parameter vector can still expose the
missing provenance.

For that reason a structured source is a speculative positive approximation.
It may unlock native Djinn construction or Exference's one-layer projection,
but every resulting candidate must pass Lean kernel elaboration at the exact
original type. It contributes no new negative evidence: recursive occurrences
already prevent Djinn exhaustion from becoming an uninhabitation proof, and
Exference never reports one. A future serializer can replace the approximation
with faithful generic reconstruction by carrying declaration-parameter
provenance explicitly.

## Validation coverage

At the initial implementation commits, the focused Haskell suite contains 106
unit tests. The recursive-family cases cover:

- direct `List` rank-N transport under Djinn and Exference;
- native Djinn construction of a polymorphic recursive family;
- composition of two independent native recursive SCCs, with same-SCC
  reopening and false negative evidence excluded;
- a live provider supplying the only useful source occurrence, in both
  provider orders;
- normalization of differently spelled recursive self knots;
- reachability isolation for an unused abstract outer inventory;
- occurrence-specialized fitting of a structured rank-N constructor field;
- complete/partial mixtures, repeated parameters, incompatible schemas, and a
  recursive/nominal collision falling back without `match`;
- constructor introduction surviving that abstract fallback;
- exact-head separation despite shared display keys and constructor names;
- arity disagreement rejection; and
- preservation of the established one-layer `Nat`, `List.map`, and fixed-field
  `Std.Format` behavior.

The successor adds focused controls for generic payload projection,
impredicative payload projection with a wildcard recursive tail, and native
Djinn construction from a structured recursive parameter without exposing a
reopenable recursive constructor premise.

The fifth end-to-end golden,
[`synth-recursive-rankn.txt`](../../test/synth-recursive-rankn.txt), declares:

```lean
inductive Demo.RecBox (a : Type 1) : Type 1 where
| step : a → Demo.RecBox a → Demo.RecBox a
```

It first checks the same impredicative transport under standalone Exference and
Djinn. `RecBox` deliberately has no base constructor: its only constructor
requires both an `a` and an existing recursive knot, so constructor
introduction cannot fake the expected `fun x => x _`.

The transcript then declares independent recursive `Demo.Inner` and
`Demo.Outer` families. An unused generic observer supplies the complete
plain-parameter schema needed for native planning without offering an `Outer`
result. From a nested `forall` payload premise, standalone Djinn must therefore
construct and Lean 4.31 must verify:

```lean
fun _ x => .wrap (.done x)
```

This live control distinguishes the native two-SCC projection from the
abstract constructor-premise fallback. At the implementation commits above,
all 106 focused tests and all five live golden transcripts pass.

## Deliberate boundary

Query-wide identity is not recursive synthesis. The implementation does not
derive folds, maps, induction hypotheses, termination arguments, or nested
recursive eliminations. Its largest rank-N/impredicative benefit is direct
transport of an existing polymorphic family value; Exference's one-layer case
analysis is a separately bounded convenience. Goals beyond those boundaries
remain provider work, prove-mode work, or honest bounded misses.
