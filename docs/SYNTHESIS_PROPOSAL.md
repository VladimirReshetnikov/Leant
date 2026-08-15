# Proposal: automatic term synthesis in Leant, borrowing from Djex

*Status: phases 0–2 implemented (`:synth` in this repository, engines =
in-process Djex Djinn/LJT and Exference; see
[README.md](../README.md#synth--automatic-term-synthesis)). A bounded
first slice of phase 3 is also implemented: live goal-relevant Lean
providers, exact global rendering, relevance-preserving ratings, curated rated
`List`/`Nat` library premises, and one-layer recursive elimination, backed by a
bounded semantic provider cache. Every engine mode protects structural
synthesis with a Lean-verified provider-free baseline and consults provider or
library inventory whenever no baseline term verifies. Complete Djinn
refutations are retained as proof-backed fallbacks while constructive provider
lanes run; a verified provider candidate wins, and otherwise the refutation is
restored before any classical retry. Djinn-backed fallback can
specialize loaded schemes at closed monotypes and guarded rank-N polytypes.
An independently scheduled positive-only Djinn tail can now specialize
query-local hypotheses at closed forall-free monotypes already present in the
checked goal, without changing historical local or loaded-scheme prefixes.
Both engines can also retain a query-supplied closed polytype at a vacuous
local provider whose result mentions fixed ambient query variables. Live
provider discovery can now attach bounded, provider-local, ordered proper-type
assignments established by Lean's active instance heads, allowing both engines
to select correlated rank-N provider arguments which are absent from the query
without importing Lean dictionaries into Djex. The translator additionally
retains first-order proper-type applications for bound
constructor variables and opaque Lean families, and shares compatible
proper-type applications of non-recursive and recursive inductive families
across the complete query. Finite data retains constructor introduction and
case elimination; recursive data retains direct rank-N transport in both
engines and a validated one-layer eliminator in Exference. That eliminator
preserves the established strict candidate prefix, retrying with intentionally
unused inputs only after a strict search miss and rendering omitted fields as
Lean wildcards. Phase 4 and a persistent Mathlib-scale inventory remain future
work; the implemented post-phase-2 increments are detailed in §7. Companion to
[PROPOSALS.md](PROPOSALS.md).*

Djex — vendored read-only in this repository as the
[`lib/Djex`](../lib/Djex) submodule (pinned by the repository gitlink) —
merges two Haskell expression synthesizers — Djinn
(Dyckhoff's LJT calculus: complete, terminating intuitionistic proof
search that emits programs) and Exference (ranked heuristic search with
resource budgets and type-class evidence) — behind one
parser-independent "synthesis foundation" and a single library contract.
This document analyzes which of its ideas transfer to Lean 4 term
synthesis inside Leant, what they would buy us, and how to build it.

## 1. What Djex actually provides (and what maps)

*Scope note: Djex has moved well past the original Djinn and Exference.
Recent work (reviewed from the commit history and the dated reports
through 2026-08-06) adds bounded rank-N quantification, guarded
impredicative instantiation, a unified type-class constraint contract,
and bounded recursive deconstruction in Exference; §1.5 summarizes
that implemented scope and §2.0 analyzes how it maps onto Lean's type
system.*

| Djex idea | Substance | Lean/Leant mapping |
| --- | --- | --- |
| **LJT engine (Djinn)** | Complete, *terminating* proof search for intuitionistic propositional logic over `->`, tuples, `Either`, `Void`, opaque type variables; emits a lambda term, or a definitive "no term exists" | Curry–Howard transfers directly: the same calculus decides the Lean fragment `→ × ⊕ Empty Unit` in `Type` and `→ ∧ ∨ ⊥ ⊤ ¬ ↔` in `Prop`, emitting `fun`/`⟨,⟩`/`Sum.inl`/`.casesOn` terms |
| **Non-inhabitation verdicts** | "Proof-backed non-inhabitation result... when formula translation is complete" (library-api.md) | For *opaque* type variables, LJT failure means **no closed term exists at that polymorphic type** — a trustworthy negative answer no Lean tactic currently gives (`exact?` failing proves nothing) |
| **Exference engine and live inventory** | Best-first search over an *inventory* of typed constants with per-name ratings (`environment/*.ratings`), explicit step/queue/depth budgets, ranked candidate batches | The implemented phase-3 slice protects every structurally accepted mode with a Lean-verified provider-free baseline, then discovers a bounded live inventory whenever no baseline term verifies. A complete Djinn refutation is retained as fallback while those constructive lanes run; a verified provider candidate wins, and otherwise the refutation is restored. Exference applies relevance penalties; Djinn first isolates the highest-ranked provider and can instantiate retained polymorphic schemes. Exact-result ordering, worker demotion, and a generation-aware semantic cache serve both. A curated core `List`/`Nat` inventory and project `leant.ratings` overrides are implemented; a persistent Mathlib-scale index and transitive relevance remain future work |
| **Shared synthesis foundation** | Parser-independent vocabulary (`Name`, `Type`, `Constraint`, `Environment → Inventory → PreparedInventory → QueryResult (SearchBatch Candidate) → Expression`), each arrow a checked boundary | The template for Leant's internal engine boundary: one fragment grammar, one candidate term grammar, one verification protocol, with the engine behind it swappable. Leant links Djex in-process |
| **Verification posture** | Engines are explicit about semantics ("neither backend guesses the other's"); truncated batches are labeled; a finished heuristic batch with no candidates "is not a proof of non-inhabitation" | Leant goes one better: **every candidate is elaborated by the Lean backend before display** (`example : (T) := term`), so the synthesizer never needs to be trusted — the same outsource-soundness pattern `:search?` and prove mode already use |
| **Embeddable library** | `build-depends: djex`, GHC 9.12.4, sealed session + checked request + result envelope; also three CLIs (`djex djinn --render expression "a -> a"`) | Leant is built with **the same GHC 9.12.4** — it links Djex directly as a library, in-process, with no subprocess or protocol overhead |
| **Shared REPL conventions** | Explicit backend selection (`djinn`/`exference`/`both`), settable limits, environment files | `:synth` command options: engine choice, candidate count, budget — consistent with Leant's `:set`-style toggles |

## 1.5 The post-merger scope: what Djex implements today

The current engines go beyond propositional LJT and monomorphic
best-first search. From the commit history and the reports
`2026-07-28-rank-n-inference-review.md`,
`2026-07-29-hypothesis-instantiation.md`,
`2026-08-01-triple-rank-n-frontiers.md`,
`2026-08-01-four-binder-instantiation.md`, and
`2026-08-06-quartic-rank-n-frontiers.md`, with the Leant integration recorded
in `2026-08-06-quintic-rank-n-frontiers.md`, the historical five-binder
boundary in `2026-08-09-five-binder-instantiation.md`, and its shared
six-binder successor in `2026-08-10-six-binder-instantiation.md`:

- **Alpha-aware opaque atoms as the default boundary.** Quantified
  subterms are carried as alpha-normalized `TypeAtom`s with lexical
  scoping; ordinary unification never decomposes an atom. Everything
  below is a *bounded relaxation* of that default.
- **Positive rank-N opening (Djinn).** Goal-position `forall`s open into
  occurrence-scoped skolems via a polarized translation (arrow domains
  reverse polarity; products/sums preserve it). Search runs a *plan
  family*: the fully-opened and fully-opaque plans, the historical two
  singleton occurrence frontiers, followed by deterministic pair, triple,
  quadruple, and quintuple opaque/open tails. Nested selections open the union
  of their required ancestor chains. Quintuple selections alternate from both
  source edges and stop at 512 compiled plans per orientation. That fixed cap
  retains every one of the 252 ten-site and 462 eleven-site choices, making the
  family exhaustive through eleven independent sites without enumerating a
  power set. A central six-open/six-opaque choice at twelve sites is the next
  deliberate, documented gap.
- **Lean forall-spine parity.** Lean serializes one written multi-binder Pi as
  adjacent `FAll` nodes because rendering must retain every explicitness slot.
  Leant `378f866` coalesces each uninterrupted spine to one Djex `ForallType`
  binder list, but never crosses an `FInst`. This preserves scope and Lean
  rendering while making a non-vacuous seven-binder source scheme one Djinn
  occurrence site, matching Djex's native Haskell representation. The live
  `synth-quintic-rankn` regression consequently exercises a genuine ten-site
  non-prefix five-opaque/five-open plan and the separate eleven-site
  five-open/six-opaque dual. Both direct candidates are checked by Lean.
- **Concrete boxed products and scoped-arrow forwarding (Exference).** A
  known nonempty boxed-product goal can be materialized as one structural tree
  before its leaves are scheduled, while the historical one-layer alternative
  remains available for reuse of an existing inner product. A split scoped
  binding also retains its complete arrow scheme, so Exference tries exact
  whole-value forwarding before eta expansion. Djex `f3dd2495` pins that
  combination. The quartic Leant submodule revision, `c0c1a461`, follows it by
  carrying tuple-goal provenance: an independently scheduled structural route
  may take the eager whole-tree shortcut once, while fields emitted by the
  shallow sibling stay shallow through later engine steps. This suppresses
  recursive shortcut duplication without losing scoped or environment product
  reuse deep in the tree. In Leant's live `synth-quartic-rankn` regression,
  each vacuous surface
  scheme `forall A B C D E : Type, Q` is serialized, after the outer `FAll`
  binders for `Q`, `R`, `Z`, and `M`, as five ordinary arrows from the shared
  opaque `Type` atom to its codomain. It is not another `FAll`; among the eight
  result leaves, only the four identity leaves stay quantified. Thus this
  bridge regression does not exercise the leading-binder
  hypothesis-instantiation guard. Standalone Exference admits the direct,
  independently checked candidate at step 30 under the unchanged
  4096-step/1024-queue bounds. Its live transcript still reports a step-limited
  tail with 39,308 queue prunes because search continues after that candidate;
  the note is not a claim of exhaustive completion. (The prune count tracks
  the regenerated `test/synth-quartic-rankn.golden` and moves with it.)
- **Bounded hypothesis-side instantiation (Djinn).** A quantified
  hypothesis generates bounded premise axioms
  `Opaque(∀ as. t) → t[as := ss]` whose instantiation candidates are
  *only types the sequent itself supplies*: goal free variables, opened
  skolems, premise scopes, and quantified atoms already mentioned. That
  last class is **guarded impredicativity** — a binder may be solved
  with a polytype, but only one the query supplied. A worklist follows
  strictly shallower exposed foralls under per-scheme and global caps;
  chains beyond six binders stay opaque. One- through three-binder tuple
  order remains historical; four-, five-, and six-binder search fairly mixes
  source-order, repeated, sparse, and Cartesian candidates under the same
  caps. This closes
  goals like
  `(forall a. a -> a) -> b -> b` and polymorphic transport through a
  container while remaining terminating.
- **Query-local closed-monotype instantiation (Djinn).** The historical local
  family above keeps its exact candidates and plan position. A separate final
  structural/nominal tail revisits only context-free schemes embedded in the
  requested goal and admits closed, forall-free subtrees collected from that
  checked query. Every retained tuple contains at least one such closed
  candidate, so the tail adds only the missing cases rather than duplicating
  historical axioms. It carries established local, loaded-scheme, and checked
  provider premises so those proof sources can compose. The family remains
  positive-only and independently capped at six binders, 16 axioms per
  scheme, 64 per family, and 512 attempts. The Leant
  [query-local closed-monotype report](reports/2026-08-09-query-local-closed-monotype-instantiation.md)
  records all-engine pure and Lean 4.31 coverage; the complete boundary suite
  retains that regression alongside the later widening.
- **Bounded loaded-scheme instantiation (Djinn).** Context-free polymorphic
  environment values retain an exact scheme alongside the historical
  implicitized premise projection. A deterministic, kind-checked tail
  specializes up to six leading binders from sequent variables, guarded
  quantified subtrees, and closed forall-free subtrees supplied by the checked
  query or loaded signatures. Work is capped and scheduled fairly across
  schemes; target-derived axioms remain diagnostic-only, so bounded positive
  search cannot manufacture recursion or an unsound negative verdict.
  The
  [`synth-six-binder-rankn`](../test/synth-six-binder-rankn.txt) transcript and
  pure boundary regressions exercise both a non-lexical six-binder hypothesis
  and a six-element active-instance provider assignment under Djinn,
  Exference, and combined mode. The
  [six-binder report](reports/2026-08-10-six-binder-instantiation.md) records
  the shared boundary and the seven-binder successor controls.
- **Guarded impredicative provider subsumption (Exference).** A
  provider such as `forall a. a -> a` forwards to an impredicative
  requested scheme; the Quick-Look-style guard admits a quantified
  instantiation image only if it occurs, up to alpha equivalence, as a
  quantified subtree of the requested scheme: "no quantifier the query
  did not supply is ever invented". Scoped providers instantiate their
  complete leading forall chain freshly per use; provider contexts
  become proof obligations. A separate bounded route for vacuous provider
  binders appends alpha-deduplicated, complete, lexically closed, context-free
  `forall` roots found in proven proper-type query positions after the
  established monotype candidates. The provider may retain ambient rigids
  opened from the same query but no unresolved free flexible variable.
  Exference's internal Haskell-instance-head route remains a monotype-only
  source of choices; the separately checked caller-evidence channel below may
  carry a quantified proper type justified by a richer source frontend.
- **Lean-visible provider instantiation evidence (Leant bridge).** Live
  provider discovery records the original names of leading type
  binders. The live wire preserves every supported non-dependent provider
  instance context as a bounded exact nominal class binder. Exference retains
  it for plain/binder-only providers and exact-evidence providers with at least
  one accepted fact group; a no-group exact-evidence provider uses its
  successfully translatable bounded vectors through the erased fallback.
  Djinn keeps its historical context-erased provider compatibility projection.
  Djex can therefore retain a vacuous specialization as an explicit type
  application, and Leant restores it with a named Lean argument such as
  `global («a» := Nat)`. Intervening class binders remain implicit for Lean's
  instance search. Specified quantified arguments use a shared closed,
  alpha-normalized representation distinct from the inferred placeholder, so
  Leant can render `global («a» := (∀ (a0_0 : _), a0_0 → a0_0))`
  structurally while preserving nested shadowing. A positional local
  application receives bounded `_`, `Type _`, and `Prop` binder-domain
  variants because Lean may lack enough expected-type information to solve the
  quantified argument's universe from `_` alone; backend verification chooses
  the first elaborating spelling. Named globals retain their source-directed
  rendering. Each of the inferred, `Type _`, and `Prop` lanes retains its own
  12 site-and-style variants, so selective local instantiation sites remain
  reachable under a hard 36-spelling bound; domain-insensitive duplicates
  collapse back to the historical group size. A provider scheme or an exact
  assignment argument may retain a structured nominal Lean class head,
  ordered bounded-kinded arguments, and body. Djex therefore checks a semantic
  class constraint and Leant renders the same Lean class application; it never
  guesses source syntax from a Haskell constraint. Dependent or unsupported
  provider contexts truncate and drop that provider instead of silently
  strengthening it through erasure. Legacy raw `FInst`,
  malformed, free, dictionary-dependent, term-indexed, and otherwise
  unsupported contexts fail closed. Unused implicit term binders are not
  misclassified as type quantifiers, and ordinary goal serialization keeps its
  established render-only behavior.
- **Correlated active-instance assignments (Leant bridge).** For each exact
  live provider independently, the generated Lean metaprogram opens at most
  six leading type binders while retaining the source instance
  constraints which can determine them. It inspects at most 32 active instance
  heads per provider in Lean resolver order. Every selected head and its full
  constraint closure run under `Lean.withoutModifyingState`, so no attempt can
  constrain the next one. The selected head stays fixed while its returned
  instance subgoals and every other provider constraint are synthesized under
  the same metavariable context. A failure or unresolved binder rejects that
  head as a whole.

  One success yields one complete ordered argument vector. At most 16
  alpha-distinct vectors survive per provider; Leant never flattens them into a
  scalar pool or reconstructs cross-head Cartesian products. Every argument
  must be closed, and its inferred type must reduce to the bounded first-order
  kind language `Type -> ... -> Type`. Discovery retains the arrow count next
  to that exact argument; zero is proper type, while a positive count preserves
  a bare or partially applied constructor. Serialization runs in a dedicated
  exact-assignment mode. In an admitted exact-context position, a genuine
  nominal class binder in an assignment or provider scheme becomes
  `FExactContext`, which carries its exact Lean class name, bounded ordered
  kinded arguments, and body instead of pretty-printed binder text. A
  positive-arity provider-scheme argument may retain the `FAll` variable that
  binds it, either bare or partially applied only to proper-type arguments.
  Arity-zero arguments retain their full fragment. Live ground
  positive-arity assignment arguments use `(kinded N (nominal "Head" ...))`,
  carrying an exact constant head and only proper-type supplied arguments. A class binder nested in one
  of those supplied fragments remains an unsupported `FInst`; it drops that
  vector locally rather than gaining recursive exact-context authority.
  Historical fragment payloads
  remain readable for compatible nonstructural heads, but their opaque spelling
  has no structural authority. The Haskell bridge reconstructs every private
  class parameter kind, translates the structure to that checked class, and
  maps it back to the same Lean head during rendering. Canonical `Prod` and
  `Sum` are admitted only at supplied-plus-residual total arity two and use
  Djex's boxed-pair and `Either` identities directly. Legacy structural
  payloads and canonical `And`, `PProd`, `Or`, `PSum`, `Iff`, and `Not` remain
  fail-closed. A whole vector containing `FDepth` or legacy raw `FInst` still
  fails closed, as do malformed, open, dictionary-dependent, term-indexed, and
  otherwise unsupported contexts. A bounded pre-scan drops assignment vectors
  carrying inconsistent class-kind or nominal-family arity claims without
  poisoning unrelated sibling vectors.
  Ordinary goal mode keeps its render-only `FInst`. Exference retains a
  supported provider scheme's semantic exact context on the plain/binder-only
  or accepted-fact lane; a no-group exact-evidence provider takes the erased
  fallback instead. A dependent or otherwise unsupported provider context
  becomes depth truncation and the provider fails closed. Djinn preserves only
  its historical positive-search compatibility projection and gains no Length
  authority.
  The boundary is recorded in the
  [contextual provider-assignment report](reports/2026-08-09-contextual-provider-assignments.md).

  Distinct successful heads for one provider remain distinct complete vectors.
  The live higher-kind regression retains unary kind-1 alternatives
  `Higher.Wrap` and `Higher.Pair Nat` for `Higher.alternative`; Djinn ranks
  `Wrap` first, Exference ranks `Pair Nat` first, and combined mode follows the
  Djinn-first merge, but every mode must return both exact applications once.
  The same regression retains the heterogeneous vector
  `[(kind-1, Higher.Wrap), (kind-2, Higher.Triple Nat)]` for
  `Higher.multiVacuous`, proving that positional kind arities stay attached to
  one vector rather than becoming cross-head choices.

  The provider inventory grammar uses an optional
  `(instantiations (args (kinded N ...) ...))` block after binder metadata.
  `N` is the remaining `Type`-arrow arity and is bounded independently of the
  six provider-binder positions. Historical metadata-free entries,
  binder-only entries, and explicit empty blocks still parse. Historical exact
  arguments without the wrapper remain in their original vectors and default
  each position to proper kind. The legacy `(candidates ...)` form remains
  readable as unary proper-kind search hints, but retains a distinct provenance
  tag, has its provider context erased in both projections, and cannot authorize
  an inventory class fact. Neither compatibility path recreates a multi-binder
  product. Assignments stay inside the same `ProviderFrag` as their declaration,
  so the 1/4/16/full provider-prefix schedule cannot expose
  a later provider's vector in an earlier lane. Leant caps the command-wide
  association list at 32 complete vectors before any argument participates in
  family planning, rigidity, or translation.

  Exact live `(instantiations ...)` metadata has one additional checked use.
  After Lean has fixed a top-level active instance head and closed that head's
  subgoals plus every provider constraint in one isolated metavariable context,
  Leant substitutes the complete closed vector into the source provider's
  leading constraints. The whole specialized constraint group must be closed,
  forall-free, ground, and accepted transactionally by a trial seal of the
  complete production Exference inventory. Each novel member of an accepted
  group becomes a Djex instance declaration with no binders or prerequisites;
  duplicate facts are reused. The assignment
  itself remains provider-local; the derived ground class fact is
  inventory-global and may discharge a matching obligation on a
  different provider, because the Lean evidence came from top-level global
  instance resolution rather than a query given. Legacy `(candidates ...)`
  payloads and incomplete or unsupported vectors contribute no such facts.
  Accepted facts follow all provider values in stable
  provider/vector/constraint order. In Exference, vectors with accepted
  contextual facts do not also enter the historical context-free assignment
  adapter. An exact-evidence provider with no accepted group recovers all
  successfully translatable vectors from its bounded, filtered erased
  fallback; an explicit empty exact evidence block emits no fact and has no
  assignment to replay.
  Djinn's erased projection keeps its historical assignment behavior.

  Length consumes this declaration only through its independently sealed static
  resolver. A contextual Exference certificate must retain the activated ground
  obligation, Handoff must select the conditional provider summary, and Djex
  must discharge every obligation and audit the complete protected provider
  prefix before sealing a Length problem or query. The public graph projection
  has lost that association and remains non-authoritative. There are no query
  givens, and Z3 is downstream arithmetic evidence only; it cannot supply a
  dictionary or discharge receipt. Conditional sessions use policies 8/9/10,
  ground-discharged candidates use v3, and concrete encodings use 4/5/6;
  conditional provider/semantic inventories use v3/v2 while every legacy
  identity remains exact. The complete boundary is recorded in the
  [live contextual-provider ground-discharge report](reports/2026-08-13-live-contextual-provider-ground-discharge.md).

  Live discovery, wire parsing, and engine filtering admit at most 64
  `Type`-arrow domains in one argument kind. For a context-free provider source,
  Leant reconstructs the resulting at-most-129-node Djex `GroundKind` values
  and constructs
  `KindedProviderInstantiationAssignment` records. The pinned Djex API exposes
  checked `runDjinnQueryWithKindedInstantiationAssignments` and
  `runExferenceQueryWithKindedInstantiationAssignments` runners. Each resolves
  the exact sealed-session provider and validates vector width, exact arity, and
  scheme context. It then productively preflights all kinds in that assignment
  before recursive kind inference, same-provider comparison, conversion, or
  paired type elaboration. Oversized or cyclic caller-built kinds fail
  finitely. Only after that guard does the runner check the supplied binder-kind
  vector against the retained provider body, elaborate every argument at its
  supplied positional kind, check closure and context freedom, prove the whole
  specialization, and alpha-deduplicate complete vectors within that provider.
  Djinn compiles each vector into one proof-producing direct premise;
  Exference tries it once at exact global lookup. Because the caller supplies a
  kind fact which an erased body cannot infer, both paths now accept
  constraint-only or otherwise vacuous higher-kinded binders as well as
  non-vacuous ones. Neither path donates a choice to an alpha-identically typed
  sibling or rebuilds a Cartesian product. Exact contextual Exference vectors
  with accepted fact groups instead take only the replay-isolated ground-fact
  path above and never enter this context-free adapter; an exact-evidence
  provider with no accepted group recovers all successfully translatable
  vectors from its bounded, filtered erased assignment list. Empty kinded input
  is exactly inert.
  The earlier scalar and unkinded assignment APIs remain compatibility paths;
  the unkinded route still defaults an unconstrained binder to `Type`. This is
  bounded caller-supplied evidence, not general rank-N subsumption or
  impredicative inference; see the
  [correlated assignment report](reports/2026-08-05-correlated-instance-head-assignments.md).

  Canonical nominal `Prod` and `Sum` are supported bare or partially applied at
  total arity two. They share the direct structural identities used by
  saturated products and sums. Unsaturated `And`, `PProd`, `Or`, `PSum`, `Iff`,
  and `Not`, together with every legacy structural payload, remain excluded;
  saturated uses keep their structural translation. Unit regressions cover the
  kinded wire, kind/order retention,
  bounds, whole-vector deduplication, and exact vacuous success in Djinn,
  Exference, and combined mode. The live
  `synth-provider-higher-kind-assignment` transcript requires its mixed
  kinded/rank-N vector, the heterogeneous arity-1/arity-2 multi-vacuous vector,
  and both exact `Wrap` and `Pair Nat` alternatives for one provider in all
  three modes while leaving their order to engine ranking. The focused
  `synth-provider-structural-assignment` transcript additionally requires a
  provider to consume bare `Prod` and partial `Sum`, and retains both inside a
  closed contextual rank-N argument, under all three engine modes. See the
  [higher-kinded contextual assignment report](reports/2026-08-10-higher-kinded-contextual-assignments.md).
- **Instance-implicit goal alignment (Leant bridge).** A non-dependent
  instance binder is neither a type quantifier nor an ordinary engine premise.
  The fragment retains it as a render-only slot, erases its dictionary before
  search, and inserts a wildcard into an introduced Lean lambda. Nested
  instance arguments at hypothesis and provider uses remain implicit, so Lean
  reconstructs them during verification. Since the erased dictionary can
  carry proof power, Djinn exhaustion across this boundary is inconclusive.
- **Retained proper-type applications (Leant bridge).** The Lean serializer
  now preserves ordered applications headed by either a bound first-order
  type constructor or an opaque/non-inductive Lean constant. Bound heads
  become higher-kinded Djex variables; constants share collision-free rigid
  `AbstractTypeDeclaration`s across goal and provider occurrences, with an
  exact-name map for visible type-argument rendering. This makes both engines
  synthesize `(forall a, Wrap a) -> Wrap (forall b, b -> b)` and its
  constructor-variable analogue. Only arguments whose inferred type is a
  universe qualify, so term-indexed families remain opaque. Constant-headed
  applications poison negative evidence, and Lean still verifies every
  positive candidate.
- **Query-wide proper-type inductive families (Leant bridge).** A qualifying
  inductive serializes as an exact head, an ordered vector of
  proper-type parameters, and its complete occurrence-specialized constructor
  inventory. Before translation, Leant collects every use from the goal,
  caller premises, and usable providers and chooses one representation for the
  head. For non-recursive data, a unique compatible generic schema becomes one
  parameterized Djex `data` declaration; constructor maps retain the generic
  formals and recover the actual occurrence fields while rendering. Thus
  `Option`, `Except`, and user inductives support guarded
  rank-N/impredicative transport in both engines while keeping constructor
  introduction and case elimination.
  Fixed opaque fields become private rigid proper types rather than accidental
  free declaration variables. Ambiguous/repeated parameter vectors,
  incompatible schemas, or a structural/nominal collision
  conservatively choose one abstract family for the whole query. That fallback
  can still transport values but exposes no constructors and forfeits Djinn
  negative evidence. Term/dependent parameters retain the established
  occurrence-local path. Conflicting arities for one exact head are rejected
  rather than conflated.

  Recursive `FParamRec` uses follow a recursive-specific version of the same
  plan. Blocked self atoms are normalized to the exact applied family before
  schemas are compared. A complete occurrence with pairwise-distinct
  proper-type parameters may give both engines one query-wide parameterized
  recursive declaration. Plain variables carry the clearest generic evidence;
  a structured parameter is only a positive speculative approximation because
  occurrence-specialized constructor fields do not record which fragments came
  from the declaration's original parameters. Closure, specialization back to
  every observed occurrence, and template-equivalence checks constrain that
  approximation, and Lean kernel verification remains mandatory for every
  generated term. It supplies no new negative evidence. Djinn receives bounded
  positive constructor introduction from the native declaration; Exference
  retains its established one-layer match.
  Partial inventories, incompatible schemas, nominal collisions, and
  unrecoverable templates use that same abstract-plus-premises representation
  in both engines. Planning discovers nested exact families through a
  reachability-aware fixed point: it follows only selected data templates and
  active constructor premises, so unused inventories cannot affect a plan.
  Fixed opaque fields use the private rigid-type mechanism, while recursive
  self keys are excluded from that seed so the shared knot resolves through
  `tsInds`. This keeps zero-parameter providers such as `Std.Format` well
  scoped.
- **Bounded recursive deconstruction (Exference).** Recursive datatype
  declarations remain available to search, but matching stops after one
  constructor layer. Recursive fields enter that branch as ordinary
  providers and are not eagerly deconstructed again. Exference first keeps its
  usual all-inputs-used policy. Only when that lane produces no renderable
  candidate group does Leant rerun the same query with unused inputs admitted,
  so a payload may be returned while the recursive tail is ignored. The
  renderer turns the ignored pattern binder into `_`. This admits useful finite
  case terms without turning the engine into a recursion or induction
  synthesizer.
- **Verdict honesty as a fixed soundness bug.** Djinn once approximated
  every nested forall as one proposition and could report
  `ProvedUninhabitable` for inhabited types like
  `c -> (forall a. a -> a)`. The polarized translation now records
  whether any occurrence stayed opaque; an exhausted search over an
  approximated space is `NoEvidence`, never a refutation. Negative
  verdicts require a complete translation.
- **Unified class-constraint contract.** Both engines share one
  `Constraint` syntax and one explicit resolution policy; Djinn
  validates contexts (existence, arity, kinds) and synthesizes
  dictionary-independent terms; Exference resolves givens, superclasses,
  and instances, with direct provider contexts becoming obligations.
- **One classifier for search and checking.** Provider use is
  classified once "by semantic root shape" and consumed by both the
  search and the independent expression checker, so the two cannot
  drift.

Djex continues expanding in this direction. Goal-side forall introduction,
historical bounded hypothesis instantiation, the additive query-local
closed-monotype tail, and loaded-scheme specialization are all implemented
behind the same narrow library boundary, so later improvements continue to
arrive in Leant by version bump.

Two Djex components deliberately do *not* map:

- **Type-class evidence resolution** (Exference's givens/superclasses/
  instances): Lean's elaborator already resolves instances better than we
  could; synthesized terms should simply leave instance arguments
  implicit and let the backend's elaboration fill them. Djinn's honest
  stance — validate the context, "deliberately withhold class methods"
  from the proof environment — is the right initial posture for Leant too.
- **Haskell-source environment loading**: Leant's inventory comes from
  the live Lean environment via metaprograms, which is strictly better
  than parsing source files.

## 2.0 Applicability of the expanded scope to Lean's type system

The rank-N and impredicativity work is where the Haskell/Lean comparison
gets genuinely interesting, because the two systems are asymmetric in
opposite directions.

### What becomes *easier* in Lean

- **Rank-N is native.** Haskell's surface language is prenex; Djex's
  polarized translation, occurrence-scoped skolems, and plan frontiers
  are careful engineering *around* that. Lean has uniform Π-types:
  `(∀ a, a → a) → b → b` is an unremarkable type, goal-side
  ∀-introduction is literally `intro`, while Djex needs an explicit
  bounded introduction rule. What
  transfers is not the workaround but the *logic*: positive ∀ =
  introduce a fresh opaque atom (Lean: a local constant), negative ∀ =
  bounded instantiation rule. Djex's deterministic singleton, pairwise,
  triple, quadruple, and bounded quintuple frontiers transfer as a deterministic
  search-space cap. The quintic tail keeps at most 512 plans in each
  orientation, which is still exhaustive through eleven independent sites
  without becoming a power set.
- **Instantiation evidence is trivial.** Djex manufactures reserved
  `$`-namespace axiom symbols and erases them before code generation
  because GHC re-instantiates value occurrences implicitly. In Lean the
  evidence for "use `h : ∀ α, α → α` at `B`" is just the application
  `h B` (or bare `h`, letting the elaborator unify) — no erasure
  machinery at all.
- **The independent checker comes for free.** Djex maintains its own
  expression checker sharing a classifier with search. Leant's
  architecture already outsources checking to the Lean kernel — which
  also silently enforces the one constraint Haskell doesn't have:
  **universe correctness**. In `Type u` Lean is predicative
  (`(∀ α : Type, α → α) : Type 1` cannot instantiate an `α : Type`
  binder); the engine may propose universe-sloppy candidates and
  verification discards them. No universe reasoning needs to live in
  the engine.
- **Class contexts collapse into elaboration.** Djex implements nominal
  instance resolution (givens, superclasses, instances). In Lean, a
  non-dependent instance-implicit binder `[Monad m]` is retained only as a
  render position and incompleteness witness; neither engine receives its
  dictionary as proof power. A candidate that uses a constrained hypothesis or
  class method leaves the instance argument implicit. Lean's elaborator,
  running during verification, is a better evidence resolver than anything we
  would port.

### What becomes *harder* in Lean — and why Djex's shape is still right

- **`Prop` is genuinely impredicative**, so the space of legal
  instantiations is *larger* than in (predicative-by-default) Haskell:
  `∀ p : Prop, ...` may be instantiated at any proposition, including
  quantified ones. Full second-order intuitionistic propositional
  inhabitation is undecidable, so *some* bound is mandatory, and Djex's
  guarded rule — instantiate only with polytypes the query itself
  supplies, up to alpha equivalence — is exactly the right bound: it is
  sound, terminating, closes the practically common goals
  (polymorphic transport, self-application patterns like
  `(∀ p, p → p) → q → q`), and fails *honestly* on the rest. In Lean
  this guard is not a stopgap before a complete solver arrives; it is
  the correct permanent design for an undecidable problem.
- **Verdict semantics need Djex's fixed honesty rule, extended.**
  Djinn's lesson — negative evidence only from complete translations —
  becomes a two-axis rule in Leant: a "provably no closed term" verdict
  requires (a) no quantified occurrence was left opaque or
  bounded-instantiated, *and* (b) no atom is hiding dependent
  structure. Otherwise the result is "no term found within bounds",
  Djex's `NoEvidence`.
- **Dependent types remain outside the engine** — but the alpha-aware
  opaque-atom discipline upgrades them from *refusal* to *atoms*. A
  goal like `(∀ n : Nat, P n) → Q → (∀ n : Nat, P n)` is solvable
  propositionally: the dependent subformulas alpha-normalize to equal
  atoms and LJT finds `fun h _ => h`. This is a direct, cheap widening
  of the phase-1 fragment that the original proposal (pre-review)
  missed: dependent goals become in-scope whenever their dependent
  parts only need to be *transported*, not *analyzed*.

### Net assessment

Djex's expanded scope is not just applicable — Lean *simplifies* most of
it (native rank-N, kernel-checked universes, elaborator-resolved
instances, trivial instantiation evidence) while *validating* the rest
(guarded impredicativity as the permanent answer to an undecidable
space; strict verdict honesty). The parts of Djex that took the most
engineering are precisely the parts Leant gets from Lean for free, which
tilts the cost/benefit further toward doing this.

## 2. Why this is worth having: benefits analysis

### 2.1 It fills a real gap between Lean's existing tools

| Tool | What it does | What it does not do |
| --- | --- | --- |
| `exact?` / `apply?` | Finds an **existing** lemma closing the goal | Cannot *compose* a new term; fails on `(A → B → C) → (A → B) → A → C` unless that exact lemma exists |
| `tauto` / `itauto` (Mathlib) | Decides propositional goals (`itauto` is intuitionistic-complete) | `Prop`-only tactics; need Mathlib imported (typically minutes of first-use latency); no term display culture, no negative verdicts, nothing for `Type` |
| `aesop` | General proof search | Heuristic, Mathlib, `Prop`-oriented, no non-inhabitation answers |
| `decide` | Decidable ground propositions | Nothing polymorphic or data-level |
| **`:synth`** | **Constructs** programs/proofs in the structural fragment, in `Type` *and* `Prop`, with core Lean only, multiple ranked candidates, and trustworthy "no closed term exists" verdicts | No dependent elimination, induction, or invented recursive definitions; Exference's recursive case analysis is deliberately one layer (see §5) |

The sweet spot is *higher-order plumbing*: currying/uncurrying,
projections, composition, distribution lemmas (`A × (B ⊕ C) → (A × B) ⊕
(A × C)`), continuation shuffles (`((A → B) → A) → (A → A)`) — terms one
writes constantly, where `:synth` answers in milliseconds with the exact
lambda, works in a bare `--plain` session, and can also say "there is
provably no such closed term" (e.g. Peirce's law, double-negation
elimination) — which is *educationally* precious: Leant's built-in help
already explains `imax` and impredicativity; a synthesizer that answers
"`((A → B) → A) → A` has no constructive inhabitant, and here is the
closest classical variant" continues that pedagogy.

### 2.2 Multiple candidates are a feature, not a luxury

`a → a → a` has two inhabitants that matter (`fun x _ => x` and
`fun _ y => y`). Djinn enumerates alternatives; Exference ranks them.
For *programs* (as opposed to proof-irrelevant `Prop`s, where any
inhabitant will do) candidate choice is the whole point — Leant should
display a numbered batch, each one already Lean-verified, and let the
user pick (`:synth` then `1`), mirroring Djex's `SearchBatch Candidate`
with explicit truncation labeling.

### 2.3 It compounds with what Leant already has

- **Prove mode**: `:synth` on the current goal becomes an `exact <term>`
  script step — a constructive complement to `:auto`'s finisher battery,
  and unlike `exact?` it needs no premise database.
- **`sorry` flow**: `sorry` already prints its goal and offers `:prove`;
  the same hook can offer synthesis when the goal is in-fragment.
- **Live environment**: the first phase-3 slice now asks Lean directly
  for a bounded, goal-relevant provider inventory. Its successful
  answers, including an empty inventory, are shared by canonical target
  roots and result head in a 12-entry generation-aware LRU. A persistent
  Mathlib-scale index remains an optimization, not a soundness
  requirement.
- **Verification loop**: `example : (T) := candidate` is one `runCmd` —
  infrastructure that exists, including timeout handling and crash
  replay.
- **A capability that plays to the Haskell implementation's strengths**:
  in-process Djex embedding is exactly where the primary implementation
  is structurally advantaged (same GHC, direct library linkage, no IPC),
  giving the two implementations complementary rather than duplicate
  roles.

## 3. Architecture

```
 Lean type/goal (string)
        |  backend: #check-normalize, pp with explicit binders
        v
 Fragment translator  ── out-of-fragment ──> honest refusal (":synth handles
        |                                    →/×/⊕/∀(non-dep)/⊥/⊤ over opaque
        v                                    variables; this goal uses X")
 Search policy (provider-free verified baseline, then optional bounded
                live-provider stages; semantic 12-entry LRU)
        |
        v
 Engine (Djinn/LJT or ranked Exference)
        |         candidates (internal term grammar)
        v
 Lean renderer (fun/⟨,⟩/Sum.casesOn/False.elim/absurd...)
        |
        v
 Backend verification: example : (T) := term   [reject failures silently]
        |
        v
 Ranked, verified batch  ->  user picks  ->  session/`it`/prove-script
```

The diagram compresses the verified lane policy. Every engine mode starts a
structurally accepted fragment with a provider-free search. Lean verifies that
lane's rendered candidates before Leant discovers live providers. A verified
term ends the command. If no term verifies, Exference searches the full bounded
inventory while Djinn-backed modes try discovery-order prefixes of 1, 4, and
16 providers before the full inventory. A complete provider-free Djinn
refutation is retained across those lanes and restored if none produces a
Lean-verified candidate.
Provider-eligible
atomic/refused goals skip the baseline and go
directly to those stages. In a combined invocation, fresh candidate groups are
scheduled `D1–D4, E1–E12, D5–D12`; those 24 groups retain both standalone
12-group frontiers, and later tails alternate. All stages share one command
deadline. Variants that failed earlier verification are removed from each
source stream before the later lane is forced or capped, so newly empty groups
spend no fresh slot. The
intentional tradeoff is that provider alternatives are not enumerated once a
structural baseline succeeds. See the
[provider-isolated baseline report](reports/2026-08-01-provider-isolated-exference-baseline.md).

There is a smaller strict/relaxed pair inside each Exference invocation.
Search first uses the default policy that every introduced binder must be used;
only an empty strict candidate-group prefix triggers a retry with unused inputs
allowed. Each lane may spend the configured `synth-steps` budget, but both run
under the command's single outer `LEANT_SYNTH_TIMEOUT` deadline. Thus a miss can
consume two engine step budgets without receiving a second wall-clock timeout.
This pair is independent of the provider-free/provider-enriched orchestration
above; if both provider passes are reached, each invocation applies the same
strict-first rule within the one shared command deadline.

Design rules, all inherited from Djex:

1. **Checked boundaries.** The translator refuses anything outside the
   fragment with a specific reason, like Djex's checked request edge —
   no silent wrong answers.
2. **The engine is never trusted.** Only backend-verified candidates are
   shown. This means the LJT engine does not need to be bug-free to be
   safe, and phase-3 heuristics can be arbitrarily aggressive.
3. **Negative answers are labeled by strength.** "Provably uninhabited
   (complete fragment)" vs. "search exhausted budget" — Djex's exact
   distinction between Djinn and Exference verdicts.
4. **One narrow engine boundary.** The translator/renderer speak to the
   engine through a small typed interface (goal in, candidate batch
   out), so the LJT engine, the ranked-search engine, or a
   different backend can be swapped without touching the REPL layer.
   The engine lives in the REPL as a direct Djex library dependency.

### Translation notes (the genuinely new work)

- **Into the fragment**: elaborate the goal via the backend with
  pretty-printing pinned (`set_option pp.foralls true`, explicit
  parenthesization); parse only: `∀ (x : _), T` where `x` unused
  (= arrow), `→`, `×`/`And`, `⊕`/`Or`, `Empty`/`False`, `Unit`/`True`,
  `Iff` (as pair of arrows), `¬` (as `→ False`), and opaque heads
  (variables and any constant applied to arguments, treated atomically).
  Universally quantified *type* variables at the front (`∀ {α : Sort u}`)
  become Djinn's opaque variables. **Nested quantifiers are not
  refused**: following Djex's current model, they are carried as
  alpha-normalized opaque atoms by default, opened positionally under
  the plan-family caps (§1.5/§2.0), and instantiated on the hypothesis
  side only at sequent-supplied types. **Dependent subformulas**
  (`∀ n : Nat, P n`, indexed families) likewise become opaque atoms —
  transportable, never analyzed.
- **Out of the engine**: LJT proofs are lambda terms with pairing,
  injections, and case splits; render `⟨a, b⟩`, `Sum.inl`/`Or.inl`,
  `nomatch`/`False.elim`, `.1`/`.2`. In `Prop` render the logical
  spellings, in `Type` the data spellings — the translator knows which
  side it is on from the goal's universe.

## 4. Phased plan

- **Phase 0 — spike (S).** `:synth` in the Haskell implementation only, engine =
  embedded Djex (`build-depends: djex`; same GHC). Fragment: arrows and
  opaque variables. Verify via backend, render, display batch. Proves
  the translation round-trip end to end.
- **Phase 1 — the real feature (M).** Full propositional fragment (×,
  ⊕, ⊥, ⊤, ¬, ↔, non-dependent ∀), Prop/Type-aware rendering,
  non-inhabitation verdicts, candidate numbering and selection,
  prove-mode integration (`:synth` as a tactic-step producer). Because
  the engine is today's Djex, the **bounded quantified slice comes in
  the same phase for free**: nested ∀s as opaque atoms, positive
  opening, hypothesis instantiation at query-supplied types, guarded
  impredicativity — the Leant work is confined to the translator
  (polarity- and atom-aware) and to verdict labeling (§2.0).
- **Phase 2 — local and query-wide non-recursive inductives (M/L,
  implemented).** Treat
  non-recursive, non-dependent inductives and structures as generalized
  sums of products: constructors as right-rules, `casesOn` as
  left-rules — precisely how Djinn admits Haskell `data` declarations.
  As built, the serializer expands any qualifying inductive occurrence
  (non-recursive, non-indexed, non-mutual, fully parameter-applied,
  explicit non-dependent constructor fields — the check runs on the
  *instantiated* constructor telescope, so a `Sigma` whose second
  component ignores the first qualifies too) into its constructor list;
  occurrence-local `FInd` values still receive one fresh datatype per
  alpha-normalized occurrence key, parameterized over the goal variables their
  fields mention. When every applied parameter itself inhabits a universe, the
  serializer instead emits `FParamInd`: exact Lean head, display key, ordered
  parameters, and the complete specialized constructor list. A pre-scan over
  the goal, caller premises, and usable providers chooses one exact-head plan
  before traversal can bias it. A pairwise-distinct parameter occurrence may
  supply the generic template only when substituting every other occurrence's
  parameters reproduces its constructor schema; compatible templates must be
  alpha-equivalent. The engine then declares one shared parameterized datatype
  and the renderer fits each constructor or pattern using the fields from the
  actual Lean occurrence. This covers built-ins (`Bool`, `Option`, `Ordering`,
  `Except`, `Decidable`) and session-declared types alike — no `:browse`
  machinery was needed; the instantiated-telescope route is simpler and
  stronger than fetching polymorphic constructor signatures.

  Whole-fragment substitution is capture-avoiding, nested exact-family
  inventories belong to their own plans, and a fixed opaque field receives a
  private rigid `AbstractTypeDeclaration` so a shared data declaration never
  contains an accidental free variable. If parameter positions are repeated
  or ambiguous and no later generic occurrence resolves them, constructor
  inventories disagree, or an opaque nominal use of the same head appears,
  Leant installs one abstract exact family query-wide. Positive
  nominal transport remains available, but constructors/cases and sound
  negative evidence do not. An inconsistent arity for one exact head is an
  invalid query representation and is rejected. Term/dependent parameters
  continue through the occurrence-local representation. Refutations over
  genuinely expanded inductives remain sound: the engine sees the complete
  constructor list, and Lean's elimination restrictions only make Lean *more*
  restrictive than the engine's model, never less.
- **Phase 3 — ranked environment search (L, bounded first slice
  implemented).** When any engine reaches provider search, a Lean metaprogram
  scans environment names cheaply and retains declarations whose root
  namespace occurs in the target, plus exact declarations made in the
  current session. It rejects generated names, orders exact-result
  session hits first, then exact-result public declarations, then the
  session and public fallback pools, and serializes at most 80 provider
  candidates. Conventional implementation-worker names (`TR`, `Impl`,
  `Aux`, `.go`, and `.loop`) remain eligible after those public tiers;
  exact session declarations bypass the heuristic. Providers outside the
  supported fragment are dropped individually before search. Leant gives
  the survivors private collision-free engine names and maps them back to the
  exact fully-qualified Lean globals during rendering. It also retains the
  source names of engine-visible type binders, so visible Djex
  instantiations render as named Lean arguments without exposing intervening
  instance binders. The live wire retains supported provider instance binders
  as semantic exact class contexts. Exference preserves them on the
  plain/binder-only and accepted-fact lanes, while a no-group exact-evidence
  provider and Djinn use compatibility erasure. Dependent or unsupported
  contexts drop that provider. When a provider constraint can determine the visible binders,
  discovery also records the bounded active-head assignments described in
  §1.5, including each
  argument's bounded `Type`-arrow kind. Exact `(instantiations ...)` metadata is
  provider-local and optional for specialization, while the closed class facts
  it proves enter the exact Exference inventory and can be resolved globally by
  Length. Legacy `(candidates ...)` hints never create those facts. Context-free
  source vectors reach Djex's checked kinded exact-vector runners; contextual
  Exference vectors instead authorize only the replay-isolated ground-fact
  path: discovery commits no vector state, source-order trials rebuild the
  previously accepted keys plus one candidate, and the final inventory is a
  clean replay of the accepted keys. An all-rejected provider recovers all
  successfully translatable vectors from its bounded, filtered context-erased
  historical assignment lane.
  Exference assigns increasing positive rating penalties in discovery order so fallback
  constants do not drown the best match; Djinn instead uses the sparse-prefix
  schedule below. Exference remains subject to its explicit budgets
  (`:set synth-steps` exposes the step bound; queue/depth retain conservative
  engine defaults) and reports truncation honestly. This is enough for
  `(α → β) → List α → List β` to prefer `List.map`.

  No mode puts that inventory into every structural search. For an in-fragment
  goal it first runs the ordinary structural projection with no providers,
  renders the bounded candidate prefix, and asks Lean to elaborate every tried
  variant against the exact goal. Provider discovery and enriched search happen
  whenever that baseline produces no verified term. Atomic or
  provider-open refused goals have no useful structural baseline and keep the
  direct provider path. A complete Djinn refutation is preserved as fallback
  while the constructive provider lanes run; a verified candidate overrides
  it, and an empty, unavailable, timed-out, or unsuccessful provider search
  restores it before any classical retry.
  Exference searches the ranked inventory directly; Djinn-backed modes try the
  top provider, then prefixes of 4 and 16, and finally the full inventory after
  verified misses. Milestones at or beyond the actual inventory size are
  omitted.

  All lanes share the command's one wall-clock deadline. Time spent on the
  baseline, its Lean checks, provider discovery, and earlier provider prefixes
  reduces the allowance left for wider fallback instead of granting another
  full timeout. If earlier variants fail verification, their exact rendered
  spellings are subtracted independently from each later engine stream before
  its 12- or 24-group prefix is forced; newly empty groups are dropped. This
  avoids duplicate failed backend work without letting rediscovery consume the
  fresh frontier. A successful baseline returns
  immediately, so this policy guarantees availability of a structural solution
  under provider pressure but deliberately does not enumerate provider-based
  alternatives after that success.

  Provider discovery does not key on raw goal spelling. The serializer's
  single elaboration supplies a canonical query comprising sorted,
  deduplicated target root namespaces and the final result head; generated
  result names are removed from both. Successful inventories, including
  empty ones, occupy a generation-aware 12-entry LRU, while failed
  discovery is retried rather than cached. Imports, ordinary declarations,
  their undo/reset/load/unpickle boundaries, and backend reconstruction
  advance the provider world and clear its cache. Generated `it1`, `it2`,
  … declarations cannot become providers, so appending or undoing one
  deliberately preserves the current generation and its inventories. A
  persistent Mathlib-scale index and transitive relevance across unrelated
  namespaces are still future work; curated core ratings and project-local
  `leant.ratings` overrides are implemented.

  The separate synthesis environment uses the same history boundary but
  avoids replaying a growing session from scratch: an exact history match
  reuses the cached environment, an append replays only its suffix, and a
  shortened or rewritten history falls back to replaying all entries over
  the cached import-and-serializer base. Generated result declarations are
  replayed so later goals can mention them even though they do not
  invalidate provider inventories.

  `:unpickle` now establishes an explicit base/undo barrier rather than an
  untracked environment jump. Leant keeps a managed copy for backend replay
  and reconstructs the complete newest-first undo stack for post-snapshot
  history transactionally. Its own `:pickle` also saves a synthesis-ready
  sibling keyed by main/companion content fingerprints and the serializer
  ABI. On restore, that sibling exposes snapshot-only declarations to goal
  translation and provider discovery; an external snapshot instead gets a
  best-effort serializer compiled directly over its environment, with an
  honest refusal when the Lean metaprogramming API is absent.

  For complete supported constructor inventories with safely recoverable
  parameter vectors, Exference also receives nominal recursive
  datatype declarations and may eliminate exactly one constructor
  layer. Recursive fields become branch-local ordinary providers rather
  than fresh elimination
  targets, keeping the search finite. It can therefore synthesize a
  finite `Nat`/`List` match and may delegate recursive work to a live
  provider, but it cannot invent a recursive definition, induction, or
  unbounded nested case split. Djinn retains the phase-2
  opaque-type-plus-constructor-premise behavior.
- **Phase 4 — research horizon (not scheduled).** Dependent goals,
  `Decidable` instance synthesis, interaction with `exact?` as a
  sub-oracle inside the search (Djex's `both` backend mode suggests the
  UX: run LJT and the heuristic in parallel, label the sources).

## 5. Honest limitations

- **Dependent types are transported, never analyzed**: a dependent
  subformula participates only as an opaque atom (§2.0), so goals
  needing an actual induction, rewrite, or case split on indices stay
  out of scope — those belong to prove mode and `:auto`. Fully
  dependent goals with no propositional skeleton are refused with the
  reason.
- **Quantifier verdicts are bounded, not complete**: second-order
  instantiation follows Djex's guarded, sequent-supplied discipline;
  beyond it (including instantiation chains longer than six binders
  and the twelve-site six-open/six-opaque plan gap) the answer is "no term
  found within bounds" — full impredicative inhabitation is undecidable,
  so this boundary is permanent, and the display must never upgrade it
  to a refutation. Djinn's query-local closed-monotype extension is likewise a
  final positive-only family: a miss is always NoEvidence, never a new negative
  theorem. Exference's query-derived provider route admits only
  complete closed, context-free `forall` roots observed in proven arrow or
  tuple proper-type positions; it excludes the query root and children of
  opaque type applications, and retains the six-binder and 32-combination
  caps. Its internal Haskell instance-head specialization remains
  monotype-only. Separately, Leant can supply a quantified choice which an
  active Lean instance head established for that exact provider: at most six
  leading type binders are opened, 32 heads are inspected and 16 distinct
  complete vectors retained per provider, and no more than 32 provider/vector
  associations reach a checked Djex runner. The selected head's subgoals and
  all remaining provider constraints must close under one isolated
  metavariable context. Any open, wrong-arity, depth-truncated, malformed, or
  unsupported vector fails closed as a whole. Each argument's kind must be a
  bounded `Type -> ... -> Type` chain; its arrow count crosses the bridge and
  is checked against the exact provider binder. This admits constraint-only or
  otherwise vacuous higher-kinded binders and closed quantified arguments with
  structured exact nominal class contexts. The same bounded form retains a
  supported context at a provider-scheme root; dependent or unsupported roots
  drop the provider instead of being erased. It does not admit legacy raw
  `FInst`, free, dictionary-dependent, or term-indexed contexts. Djinn keeps its
  historical context-erased positive-search projection and never supplies the
  opaque Length carrier. Canonical `Prod` and `Sum` are admitted at total arity
  two, both as direct provider
  arguments and inside structured exact contexts.
  Unsaturated `And`, `PProd`, `Or`, `PSum`, `Iff`, and `Not`, together with
  legacy structural payloads, remain excluded. A vacuous provider may mention
  ambient rigids opened from the query, but a free flexible variable still
  disables this route. Ordinary goals gain no contextual search from this
  representation. Only exact live `(instantiations ...)` closure on an
  Exference contextual provider can create a zero-prerequisite ground inventory
  fact, and only after the complete specialized constraint group passes a
  transactional trial seal; legacy `(candidates ...)` metadata cannot. Such a
  fact may serve another provider in the exact inventory because
  its Lean evidence was top-level and global, but neither query givens nor Z3
  participate. A conditional Length problem and query exist only after Djex's
  independent static discharge and protected-prefix audit.
- **Recursive elimination is bounded to one layer in Exference.** A
  recursive field exposed by a constructor match is available as a
  normal branch-local value, but is not eagerly decomposed again. The
  engine may reuse a library provider for the recursive continuation;
  it does not invent a recursive definition, induction, or unbounded
  eliminator. For a complete compatible exact family, Djinn instead keeps the
  native declaration but permits only Djex's bounded positive introduction: one
  layer per SCC and at most two independent SCCs on a logical path. Recursive
  inputs remain opaque. Exference preserves its strict ranking whenever that
  search finds a candidate; only a strict miss retries with unused inputs, and
  ignored constructor fields render as `_` rather than misleading names.
- **Query-wide recursive identity does not imply recursive synthesis.**
  `FParamRec` now preserves one exact applied family across the goal, caller
  premises, and usable providers, which enables direct rank-N transport in
  both engines. A complete compatible schema gives both engines a native
  declaration: Djinn uses bounded positive construction and Exference its
  one-layer elimination. Partial inventories, incompatible schemas,
  repeated parameter vectors with no other validating source, and nominal
  collisions receive an abstract exact family plus sound occurrence
  constructor premises. A pairwise-distinct structured parameter vector may
  now seed a native plan for positive candidate generation, but this is
  deliberately speculative: occurrence-specialized fields carry no
  declaration-parameter provenance. Observed specialization checks and final
  Lean elaboration guard the candidates; the approximation does not justify a
  negative result. This supports transport and introduction, not recursive
  definitions, induction, or unbounded deconstruction.
- **Abstract-family fallbacks do not prove absence.** If exact-head uses have
  ambiguous parameters, incompatible schemas, or mixed
  structural/nominal evidence, Leant keeps one rigid abstract family for
  positive transport and marks the projection incomplete. Unsafe structure in
  the goal or caller premises does the same. Djinn reports only "no term found
  within bounds" for exhaustion of either approximation; Exference never
  makes a negative claim. Inconsistent arities are rejected rather than sent
  through this fallback.
- **Parametricity caveat**: "uninhabited" verdicts are about *closed
  terms at the polymorphic type* — `∀ α β, α → β` being uninhabited does
  not mean a particular instantiation is empty. The display must say
  "no closed term of this polymorphic type exists", never "this is
  false"; in `Prop` the verdict must further note it is about
  *constructive* provability (Peirce's law is classically fine). In Leant this
  proof is complete for the provider-free structural calculus, not an
  exhaustive scan of the bounded, best-effort live environment inventory.
  Leant therefore retains it as fallback while trying constructive live
  providers; the first Lean-verified provider term wins, while provider
  failure or exhaustion restores the refutation.
- **Performance**: LJT on interactive-size goals is microseconds; the
  cost center is the backend verification round-trip (on the order of
  100–300 ms per candidate), so batches should verify lazily, top
  candidate first. The live inventory is capped at 80 serialized
  providers. Its bounded semantic LRU avoids repeated discovery for the
  same canonical roots/result head and provider world, while suffix-only
  history replay avoids rebuilding the synthesis environment after each
  generated result. Every mode's provider-free baseline and enriched stages
  share one wall-clock deadline; a verified baseline avoids discovery entirely,
  at the cost of not listing provider alternatives after structural success.
  Within each Exference invocation, a
  strict miss may additionally spend one fresh `synth-steps` budget on the
  allow-unused retry, still beneath that single outer deadline. Root-namespace
  relevance is intentionally shallow; a persistent Mathlib-scale relevance
  index remains open work.
- **Maintenance**: embedding Djex ties Leant to a large local
  package (and to its GHC version). Mitigation: the narrow engine
  boundary keeps Djex swappable for a small purpose-built LJT module
  later, without REPL-layer changes.

## 6. Recommendation

The review of Djex's current scope strengthens the original
recommendation: the engine now handles bounded rank-N and guarded
impredicative goals out of the box, and the analysis in §2.0 shows the
expensive parts of that machinery are either native to Lean or absorbed
by kernel-side verification — Leant's share of the work shrank while the
reachable goal space grew.

Phases 0–2 have delivered instant verified lambda terms, trustworthy
uninhabitation answers, inductive-data support, query-wide non-recursive family
transport across rank-N/impredicative arguments, and a prove-mode step
that composes rather than merely searches. The bounded phase-3 slice
now validates the live-environment design without committing Leant to a
global Mathlib index: exact globals survive the engine round-trip,
ordered penalties keep an 80-provider query useful, and one-layer
recursive elimination composes with library reuse. A bounded semantic
LRU now removes repeated inventory round-trips without changing startup
discipline, and synthesis-history appends replay only their suffix. The
next phase-3 work should measure those latency gains and improve relevance
beyond a single target root; stable project-local ratings are already exposed.

## 7. Post-phase-2 proposals

What phases 0–2 taught, turned into the next increments. Ordered by
expected value-for-effort (effort scale as in
[PROPOSALS.md](PROPOSALS.md): S < half a day, M a day or two, L
several days). Items A–D need no new engine capability — they are
translator, driver, and renderer work around the existing boundary.

### A. Prove-mode hypotheses as premises — M, highest value (implemented)

Today `:synth` in prove mode prints "(hypotheses are ignored —
synthesizing the goal target only)" and works on the bare target. That
discards exactly the information a mid-proof goal is about: after
`intro h`, the goal `⊢ B` with `h : A` in context is *unsolvable* for
the current pipeline even when `A → B` is trivially synthesizable.

Plan: the goal display is already split into context lines and target
(`goalTarget`); instead of dropping the context, translate the goal as
`(T₁) → (T₂) → ... → (target)` over the pretty-printed hypothesis
types, run the unchanged pipeline, and emit the candidate *applied to
the hypothesis names*: `exact (fun a b => body) h₁ h₂`. Verification
must move from the session-env `example : (T) := t` check to applying
`exact (...)` on the live proof state (the backend's proof-state
tactic protocol, which prove mode already uses) so local hypotheses
are in scope; a candidate that fails is dropped exactly as today.
Inaccessible hypotheses (shadowed, `✝`-marked) are skipped with a
note. This also upgrades the `sorry`-hook flow for free, since it
shares `goalTarget`.

### B. Classical fallback via Glivenko — S/M, pedagogy flagship (implemented)

§2.1 promised: "`((A → B) → A) → A` has no constructive inhabitant,
and here is the closest classical variant". Phase 1 delivered the
first half; deliver the second. When the provider-free engine soundly
refutes a `Prop` goal, Leant retains that proof-backed result while its
constructive live-provider lanes run. Only if no provider candidate survives
Lean verification does classical search begin. For a purely propositional
fragment (no quantifiers), re-run the engine once on `¬¬goal`. By Glivenko's
theorem this succeeds
*exactly* when the goal is classically provable, so the search is
complete for the fragment; a found term `t : ¬goal → False` renders as
`Classical.byContradiction t` and is backend-verified like any other
candidate. Display both verdicts:

```
λ> :synth (((a → b) → a) → a)
constructively unprovable — but classically:
  1  Classical.byContradiction (fun a => a (fun b => b (fun c => (a (fun _ => c)).elim)))
```

Quantified goals skip the fallback (Glivenko does not extend past the
propositional fragment without ¬¬-shifts; an unverified claim is worse
than none). Effort is small because the retry reuses the whole
pipeline; only the wrapper and the verdict text are new.

*As implemented, a second classical presentation runs first: one
excluded-middle premise per atomic subformula (complete for the same
fragment — intuitionistic + atom-instances of em is exactly classical
propositional logic), substituted as `Classical.em _`, so the
candidates read as the case splits a human would write
(`match Classical.em _ with | .inl x => x | .inr k => f (fun y =>
absurd y k)` for Peirce). The em search runs under a choice-point
budget — excluded-middle premises multiply the proof space, and the
backend retains an environment per verification attempt, so both the
engine's memory and the number of failing verifications must stay
bounded; a miss falls through to the complete ¬¬ route.*

### C. Golden transcript tests for `:synth` — S, overdue (implemented)

The pipeline compiles Lean metaprograms out of Haskell string
literals, parses S-expressions, drives a foreign proof engine, and
re-verifies through a subprocess — and has no tests. The three
hand-run transcripts from the phase-2 session (enumeration, transport,
`Decidable` elimination, structures, refutations, `:synth N`
selection, prove-mode integration) should become
`test//synth-*.txt` with expected-output golden files and a
small runner script diffing actual output (timing lines and the
backend-startup banner filtered). Pairs with PROPOSALS.md item 5
(`--script` mode); until that lands, plain stdin piping — which the
transcripts already use — suffices.

The implementation now also has a focused Haskell suite, run with
`cabal test leant-synth-tests --test-show-details=direct`, for fragment
and provider parsing, engine isolation, rendering, and synthesis
behavior. The shell goldens remain the true end-to-end layer and require
the Lake project to supply `repl`/`repl.exe`; an environment without
that backend can still run the focused suite.

### D. Recursive constructor introduction — M (implemented)

The initial phase-2 projection kept `Nat`, `List`, and friends abstract and
added their constructors as sound introduction premises. That representation
remains the conservative fallback for partial, incompatible, legacy, or
otherwise unsafe recursive inventories: recursive occurrences map to the
shared abstract family, no `match` is exposed, and negative verdicts are
downgraded.

The query-wide exact-family follow-up upgrades a complete compatible
`FParamRec` schema to one native recursive datatype in both engines. Djinn then
uses Djex's bounded positive projection—one constructor layer per recursive SCC
and at most two independent SCCs on a logical path—without gaining recursive
elimination. Exference retains its one-layer eliminator. This supports finite
construction such as `List.nil` and nested independent wrappers while still
excluding invented recursion, induction, and unbounded deconstruction.

### E. Rendering polish: anonymous constructors first — S, cosmetic (implemented)

Candidates over single-constructor structures render as
`Pair.mk a b` and `match p with | Pair.mk b _ => b`; Lean idiom is
`⟨a, b⟩` and `p.fst` (or at least `⟨b, _⟩` patterns). Offer the
anonymous-constructor spelling as the first textual variant (the
existing variant machinery plus verification already handles
preference order), and short-dot constructor names (`.some x`) where
the expected type is known. Pure renderer work; every variant is
still backend-verified.

### F. Djinn, Exference, and bounded live providers — L, phase-3 slice (implemented)

Djex's Djinn and Exference adapters sit behind the existing
`Leant.Synth.Engine` boundary, selectable via `:set synth-engine
djinn|exference|both`; `:set synth-steps` exposes Exference's step
budget while queue/depth retain conservative engine defaults. Its
structural inventory contains datatype declarations and
hypothesis premises. The implemented extension now adds up to 80
providers from the live Lean environment: target-root and exact-session
filtering bounds discovery, result-head/short-name ordering supplies a
relevance signal, Exference's increasing positive penalties preserve that
signal during heuristic search, Djinn uses the sparse-prefix schedule below,
and a private-name map restores the exact Lean global in the rendered term.
For live declarations it also carries the original names of leading
type binders. Explicit Djex instantiation evidence can then render as a
named Lean argument while class dictionaries remain implicit and are rebuilt
by the elaborator.
Providers that fall outside the fragment are dropped
individually, and Lean verification remains the final authority. The
serializer derives a stable query from sorted, deduplicated target roots
and its result head; successful inventories (including empty ones) live
in a generation-aware 12-entry LRU. Provider-affecting environment
changes invalidate that generation, while generated `itN` results do
not. Session-history appends likewise replay only their new suffix into
the cached synthesis environment.

That inventory is a fallback rather than the default input for any accepted
structural goal. Leant first runs a provider-free baseline and verifies its
candidates in Lean. It discovers and searches providers whenever no baseline
term verifies; provider-eligible atomic/refused goals still go straight to
providers. A complete Djinn refutation is retained as a sound fallback during
provider search: a verified provider candidate wins, while empty, unavailable,
timed-out, or unsuccessful search restores the refutation before classical
fallback is considered.
Exference searches the ranked inventory as one enriched lane.
Before its internal 60-candidate collection bound is applied, Leant
stable-deduplicates rendered Exference groups. The first spelling wins, but
equivalent backend histories no longer spend slots which belong to later
distinct terms; subsequent standalone and combined verification frontiers
remain 12 and 24 fresh groups respectively.
Djinn, including the Djinn half of `both`, can reuse the same declarations and
Djex now specializes context-free loaded schemes at closed monotypes or guarded
rank-N polytypes. Separately, its final query-closed family specializes only
local schemes embedded in the checked goal, at closed forall-free subtrees from
that goal; the family carries loaded and provider premises for composition but
does not treat their declarations as local schemes. Because a lossy or
irrelevant declaration can crowd Djinn's fixed candidate window, Leant tries
discovery-order prefixes of 1, 4, and 16
providers before the full bounded inventory. In `both` mode, the singleton and
terminal lanes run both engines while intermediate prefixes run Djinn only, so
Exference's step budget is not spent at every width. One command deadline
covers every stage, and variants rejected by Lean are removed source-locally
before later lane caps are taken. Within a combined lane, stable exact-spelling
deduplication schedules `D1–D4, E1–E12, D5–D12`, then alternating tails; its
24-group window preserves each engine's standalone 12-group opportunity. The
policy prevents a broad
inventory from crowding out a structural or preferred-provider term while
intentionally foregoing provider alternatives after structural success.
The complete dispatch and verification contract is recorded in the
[2026-08-01 provider-isolation report](reports/2026-08-01-provider-isolated-exference-baseline.md).

Every Exference invocation also has a strict-first omission policy. The normal
lane requires every introduced binder to be used and retains the established
candidate prefix whenever it succeeds. If it produces no renderable candidate
group, Leant reruns the same session and environment with unused inputs
allowed. This is what makes a one-layer recursive projection able to return a
payload while deliberately ignoring the recursive tail. Each lane receives
the configured step bound; the outer command deadline is not renewed. Unused
pattern bindings are rendered as `_` before Lean-facing naming and the result
must still elaborate against the exact original goal.

For complete constructor inventories whose applied parameters can be
represented safely, both engine projections model exact recursive inductives
nominally. Djinn enables bounded positive construction; Exference enables one
finite constructor match, with recursive fields retained as ordinary local
values rather than recursively eliminated. Together, these changes let the
engines discover bounded constructor terms and library reuse such as
`List.map`. In `both` mode Djinn retains the first four positions, Exference
then receives its full 12-group frontier, and Djinn groups five through twelve
complete the 24-group combined window before alternating tails. Providers add
positive capabilities, and every candidate must pass Lean verification. Any
negative verdict still comes from Djinn and is exposed only when its
completeness checks justify it.

### G. Retained proper-type applications — M (first slice implemented)

The original atom fallback erased the relation between `Wrap a` and
`Wrap (forall b, b -> b)`: each pretty-printed expression became an
unrelated flexible atom before Djex could apply its guarded
impredicativity. The implemented fragment node records the complete
safety/display key, a bound-variable or exact nominal head, and an ordered
nonempty argument vector. Serializer admission is deliberately semantic:
first-order constructor binders are chains of universe domains ending in a
universe, and each retained application argument must itself inhabit a
universe. Thus `F a` and opaque `Wrap a` are retained, while dependent
`P 3` remains an atom.

Both projections lower this node to Djex `TypeApplication`. Nominal heads
share private abstract constructors with explicit proper kinds; distinct Lean
heads remain rigid even when their display keys collide. The complete nominal
key still poisons a Djinn refutation, Exference makes no negative claim, and
Lean elaboration remains the authority for candidates. The renderer maps a
private nominal name back if it reaches a visible type argument. Pure tests
cover both engines, multiple ordered arguments, provider use, rigid-head
separation, classical atomization, depth traversal, and evidence honesty; a
Lean 4.31 transcript verifies the nominal, higher-kinded-variable, provider,
and dependent-fallback paths.

The original retained-application slice intentionally runs after
`indOf`/`recOf`, so it never steals constructor structure from a qualifying
inductive. Section H implements the complementary query-wide family rule for
non-recursive data; Section I gives recursive `FParamRec` its separate knot and
bounded-elimination policy.

### H. Query-wide proper-type inductive families — M (implemented)

The serializer now distinguishes `FParamInd`, carrying an exact head, display
key, parameters, and constructors, from legacy occurrence-local `FInd`.
Admission depends on the kind of every applied parameter, not its spelling:
each argument's inferred type must reduce to a universe. Term and dependent
parameters therefore stay on the legacy path, while structured but proper
arguments—including a query-supplied polytype—remain eligible.

Planning is query-wide and exact-head keyed. It includes the goal, caller
premises, and every provider that survived depth admission. A structural plan
exists only when one recoverable generic constructor template specializes
back to every occurrence. Parameter replacement matches whole fragments
before descending, respects alpha-equivalence, avoids binder capture, and
treats nested exact-family constructor inventories as metadata owned by the
nested family's independent plan. Repeated parameters are ambiguous unless a
different occurrence supplies a validating generic template. Distinct Lean
heads never share a plan even when display keys collide.

The structural plan creates one parameterized `DataTypeDeclaration`. Its
constructor map records generic formals, while rendering prefers the validated
fields attached to the actual result or scrutinee occurrence; this is what
keeps rank-N constructor arguments and match binders fitted correctly. Opaque
fixed fields are closed as private rigid proper-type declarations and restored
to their exact parenthesized Lean type when a visible type argument reaches the
renderer.

Any nominal use of the same head, incompatible inventory, or unrecoverable
template chooses one abstract family for all occurrences. An arity conflict is
rejected outright because no single Lean family representation can cover it.
This deliberately trades constructor search for identity-preserving transport.
It also marks Djinn's projection incomplete, as do unsafe atoms in either the
goal or caller premises, so an exhausted approximate search never becomes a
refutation. Exference has no negative evidence; positive candidates from both
engines still pass the ordinary Lean elaboration check.

Provider-free Haskell tests cover one- and two-parameter transport in both
engines. The end-to-end rank-N transcript exercises real `Option` under
standalone Exference as well as Djinn: the provider-isolated baseline protects
the direct family transport from the eighty-entry root-local inventory. It also
covers two-parameter `Phantom2` and a fixed-field `Guard` under both engines,
plus an atomic `Demo.Secret` provider control and a structurally shaped
`Unit → Demo.Secret` baseline-miss control that both require the provider lane.
A separate live transcript checks an ordinary universe-polymorphic
`Demo.sealedBox` definition through Djinn at `Nat`, an opaque session type, and
a rank-N function type, plus atomic direct-provider admission, provider-free
ordering, widening to a two-provider composition, combined-mode reuse, and a
constrained vacuous provider whose closed type choice is visible through both
engines without exposing its instance argument.
A provider-refutation-fallback transcript separately checks that a live exact
rank-N provider overrides provider-free refutation under Djinn, Exference, and
combined mode, that an exact constructive provider wins before enabled
classical fallback, and that a no-provider control retains the original sound
verdict. Pure engine tests pin direct and exact rank-N overrides plus retention
of a sound refutation when the available provider cannot inhabit the goal.
A quantified-provider transcript additionally checks a local
`{a : Type 1} → Demo.Token` value under Djinn, Exference, and combined mode.
Each engine preserves the query-supplied `∀ x : Type, x → x` choice, and the
Lean 4.31 backend accepts the renderer's `Type _`-directed positional
application. See the
[scoped local-provider report](reports/2026-08-01-scoped-quantified-local-providers.md).
A dedicated combined-frontier transcript adds seven singleton distractor
types around that constrained provider. Its first 12 rendered groups all fail
Lean's instance check; `Demo.global («a» := Demo.Good)` appears at combined
group 14 and verifies. The former append merge under a 12-group cap misses the
same query, while the source-local 24-group frontier reaches it.
A separate instance-implicit transcript checks that an outer class binder does
not consume the next synthesized lambda variable and that a constrained rank-N
hypothesis is applied with its nested dictionary left implicit. The same term
verifies under standalone Djinn, standalone Exference, and combined mode; a
pure Djinn control also pins conservative negative evidence after dictionary
erasure.
A term-parameterized `Tag` control stays on the legacy occurrence-local path.
Recursive exact-head identity is the separate extension described in Section
I. See the
[2026-08-01 technical report](reports/2026-08-01-query-wide-parametric-inductive-families.md)
for the invariants and fallback matrix.

### I. Query-wide proper-type recursive families — M (implemented)

The recursive serializer node `FParamRec` carries completeness, exact Lean
head, occurrence display key, ordered proper-type parameters, and constructors.
Planning groups these occurrences with nominal uses by exact head and checks
one arity across the goal, caller premises, and usable provider inventory. It
does not reuse the finite-data template unchecked: a recursive structural
template must come from a complete occurrence whose parameters are pairwise
distinct, be closed over private formals, specialize back to every recursive
occurrence, and agree with every other viable template.

For a plain-variable parameter vector this is ordinary generic evidence. For a
structured vector it is intentionally only a positive speculative
approximation. `FParamRec` stores fields specialized at each occurrence but not
their declaration-level parameter provenance, so whole-fragment replacement
cannot prove that a coincidentally equal fixed field was originally generic.
Closure and all-observed-occurrence fitting reject many false templates, but
they cannot establish behavior at an unseen parameter vector. Consequently
structured sources may unlock candidates that are always re-elaborated by the
Lean kernel, while recursive uses continue to withhold negative evidence.

Before template comparison, the blocked self atom serialized with an
occurrence display key is rewritten as an application of the exact head to
that occurrence's parameter vector. The ordinary capture-safe genericization
can then compare `List a`, `List b`, and structured result occurrences as one
recursive schema without relying on display keys or constructor namespaces.
Distinct exact heads remain separate even if those incidental spellings
collide, and inconsistent arities are rejected.

Exference materializes a selected plan as one parameterized recursive Djex
datatype, installing the applied occurrence in the recursive map before its
constructor fields are lowered. Matching remains the existing one-layer rule:
recursive branch fields are values, not a request for another automatic split.
The renderer prefers the constructor fields serialized on the actual result or
scrutinee occurrence and uses generic specialization only as a fallback, so a
rank-N field is fitted at the proper occurrence. Exference first searches with
all introduced inputs required. If that lane has no renderable candidate group,
it retries with omission permitted; an unused recursive field then becomes a
real `_` wildcard before Lean-facing names are assigned. Both lanes have the
configured step bound and remain beneath the one outer command timeout.

Djinn receives that native recursive datatype as well, but Djex exposes only
bounded positive constructor layers and no recursive match. Both engines use an
abstract exact family plus reachable constructor premises when an inventory is
partial, no viable pairwise-distinct source resolves repeated parameters, a
structured template fails its closure/fitting checks, schemas disagree, or
structural and nominal evidence collide. These fallbacks preserve positive
family transport but expose no recursive match and make Djinn's projection
incomplete for negative-evidence purposes.

Nested constructor inventories are metadata until lowering will consume them.
The planner therefore grows its exact-family use set to a fixed point only
through selected structural templates and constructor premises active in that
engine lane. This makes provider and traversal order irrelevant without
letting an unused abstract inventory poison another family. Fixed opaque
constructor fields are collected from the selected reachable schemas and made
rigid before translation; normalized recursive self keys are subtracted from
that seed so they resolve through the installed knot.

Focused tests cover both-engine `List` transport, provider-order independence,
self-knot normalization, occurrence-specific rank-N field fitting, native Djinn
constructor rendering, independent-SCC composition, recursive evidence
withholding, abstract fallbacks, exact-head and arity separation, and the legacy
`Nat`, `List.map`, and `Std.Format` behavior. Lean goldens verify base-less
identity transport under standalone Exference and Djinn; the Exference
transcript also displays and Lean verifies the constructor-shaped candidate
`fun x => ⟨fun _ y => y, x _⟩`. Native Djinn construction of an impredicative
payload through two independent recursive SCCs remains covered as well. The
implementation contract is recorded in the
[2026-08-01 recursive-family report](reports/2026-08-01-query-wide-recursive-family-identity.md).

### J. Library premises for recursive inductives — M, phase-3 in miniature (implemented)

Item D gave recursive inductives their introduction rules; this gives
them their library. The serializer keeps a small curated table
(`List.map`, `List.foldr`, `List.append`, `List.flatten`/`List.join`,
`Nat.add`); when the goal mentions the matching inductive, each entry
is instantiated at the goal's own types — the sort-typed locals plus
the occurrences' element types — and offered as a premise
(`(prem "List.map" TYPE)` entries after the goal S-expression). The
instantiation is *syntactic* (fresh level metavariables, direct
substitution, no unification): an auto-implicit goal variable lives at
a rigid `Sort u` that a typechecked instantiation could never meet,
yet the candidate that uses the premise re-elaborates against the
pretty-printed goal, where auto-implicits are flexible again —
verification is the arbiter, as always. The driver filters the offers
(in-fragment; no recursive inductive the goal does not itself mention;
type-level dedup so `flatten`/`join` cost one premise; capped at 8,
exact goal match first).

Two searches run and merge. The base search is untouched — same
constructor premises, no budget, so verdicts and their soundness are
exactly as before. The library search strips the recursive occurrences
to plain atoms and adds the library premises under a choice-point
budget: with nil/cons in play the engine floods any candidate window
with closed junk terms (`List.nil` inhabits every `List` goal) before
enumerating a proof that uses the goal's arguments, whereas over
sealed atoms every candidate must route through a hypothesis or an
offered function. Library candidates display first; negative verdicts
come only from the base run. `:set synth-library on|off` toggles the
whole mechanism.

Landing this exposed a latent premise-scoping bug worth recording:
premises used to be prepended *outside* the goal's leading quantifier
prefix, so on an explicit-`∀` goal a premise mentioning a quantified
variable never connected to the bound occurrences — which is why
`:synth (∀ a : Type, a → List a)` produced only `List.nil` while the
auto-implicit spelling also found `List.cons x List.nil`. Premise
antecedents now sit under the prefix (capture by the goal's binders is
precisely the intent), fixing item D's promise for explicit binders
too.

The curated table is deliberately the smallest thing that delivers
the phase-3 flagship examples (`List.map` from its type, `List.foldr`
as bounded elimination, `List.flatten`); growing it toward the
browse-env inventory with a ratings file remains phase 3 proper, and
the offer/filter/verify pipeline built here is the interface that
growth will reuse.

### K. Ratings inventory and argument-first enumeration — M (implemented)

Item J's curated table grown toward the phase-3 design, in two halves.

**The inventory.** The hardcoded `(inductive, function, arity)` table
became a rated name list: `defaultRatings` ships ~17 core `List`/`Nat`
functions in Djex's `*.ratings` format (lower is better; ≥ 100
disables), a project `leant.ratings` (lines of `Name Rating`, `#`
comments) merges over it at startup, and the merged names compile into
the synthesis prelude. Arity (leading sort-typed binders) and
subject relevance (used constants ∩ the goal's recursive inductives)
are derived from each constant's type at premise time, so growing the
inventory is editing a list, not writing code. Ratings order the
offers: they decide which instantiations survive the cap and — because
the engine now consults antecedents oldest-first — which the search
reaches for first. `List.head?` was tried and rated out: an
Option-valued codomain expands into case analysis and floods the batch
with match junk.

**The enumeration.** Measured on modeled List goals, the previous
enumeration never produced an argument-using proof within the first
300 candidates once introduction premises were present — nil-composite
junk saturated any window, so no ranking downstream could save the
`List.flatten x` sitting beyond it. Two measured non-fixes are worth
recording: the `Interleave` fair strategy still drowned (the junk tree
is bushy on both sides of every choice point), and deferring
implication application (index-first `reduceAtomicImp`) just moved the
cascade to atom arrival. The actual levers were arrival order, in both
repositories:

- *Djex* (`Consult LJT antecedent evidence oldest-first`): atom
  proofs, atom-implication buckets, and nested implications were all
  stored newest-first, so every choice point reached for the most
  recently *derived* evidence — freshly composed junk before the
  goal's own arguments and named premises. All three now store
  oldest-first; search space and completeness are untouched, only
  enumeration order moves. (One Djex test pinned a choice budget tuned
  to the old order and was recalibrated.)
- *Leant* (engine boundary): premises now enter the engine goal at the
  innermost point of the binder spine — after the goal's own arrows,
  not just under its quantifier prefix — so the goal's arguments are
  the oldest atoms in scope when the premises arrive. The renderer
  strips the premise binders from their new position behind the
  goal-arrow lambdas.

Together: `fun f x => List.map f x`, `fun x => List.flatten x`,
`fun x => List.length x`, `fun x y => List.replicate x y` are now the
*first* candidates of their queries, with the constructor-junk
candidates ranked behind or out of the window entirely. The former
`List.append` same-typed-argument residual is now closed as well. At an
atomic binary endomorphism suffix, Djinn round-robins the three oldest
sibling proofs and tries unused siblings before reusing one; every
remaining proof stays on the historical depth-first tail. With two unary
distractors this moves the direct mixed application from proof 112 to proof
12 while retaining the repeated application at proof 15. In the recorded
final run, the bounded cohort kept the established four-site rank-N stress
case at 0.52 seconds; unrestricted fairness had instead widened its
independent plans beyond a three-minute run. Leant pins the rendered mixed
term inside its twelve-group verification frontier, and the live Lean
transcript now displays both `List.append x y` and `List.append y x` for
`List a → List a → List a`.

### Explicitly not proposed

- **Dependent elimination or induction** — still prove mode's job
  (§5); the transport-only discipline is the design, not a gap.
- **Unbounded Mathlib-wide inventory now** — the first useful bounded
  slice and its 12-entry semantic cache exist, but discovery remains
  deliberately root-local. A persistent cross-session index, transitive
  relevance, and stable user/core/Mathlib ratings should land only with
  measurements that protect startup and interactive latency.
- **Engine-side universe reasoning** — kernel-side verification
  already discards universe-sloppy candidates; duplicating that in
  the engine buys nothing (§2.0).
