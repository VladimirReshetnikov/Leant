# Proposal: automatic term synthesis in Leant, borrowing from Djex

*Status: phases 0–2 implemented (`:synth` in this repository, engines =
in-process Djex Djinn/LJT and Exference; see
[README.md](../README.md#synth--automatic-term-synthesis)). A bounded
first slice of phase 3 is also implemented: live goal-relevant Lean
providers, exact global rendering, relevance-preserving ratings, and
one-layer recursive elimination, backed by a bounded semantic provider
cache. Phase 4 and a persistent, Mathlib-scale inventory remain future
work. Companion to
[PROPOSALS.md](PROPOSALS.md).*

Djex — vendored read-only in this repository as the
[`lib/Djex`](../lib/Djex) submodule (pinned at `6d6ff475`) — merges two
Haskell expression synthesizers — Djinn
(Dyckhoff's LJT calculus: complete, terminating intuitionistic proof
search that emits programs) and Exference (ranked heuristic search with
resource budgets and type-class evidence) — behind one
parser-independent "synthesis foundation" and a single library contract.
This document analyzes which of its ideas transfer to Lean 4 term
synthesis inside Leant, what they would buy us, and how to build it.

## 1. What Djex actually provides (and what maps)

*Scope note: Djex has moved well past the original Djinn and Exference.
Recent work (reviewed from the commit history and the dated reports
through 2026-07-31) adds bounded rank-N quantification, guarded
impredicative instantiation, a unified type-class constraint contract,
and bounded recursive deconstruction in Exference; §1.5 summarizes
that implemented scope and §2.0 analyzes how it maps onto Lean's type
system.*

| Djex idea | Substance | Lean/Leant mapping |
| --- | --- | --- |
| **LJT engine (Djinn)** | Complete, *terminating* proof search for intuitionistic propositional logic over `->`, tuples, `Either`, `Void`, opaque type variables; emits a lambda term, or a definitive "no term exists" | Curry–Howard transfers directly: the same calculus decides the Lean fragment `→ × ⊕ Empty Unit` in `Type` and `→ ∧ ∨ ⊥ ⊤ ¬ ↔` in `Prop`, emitting `fun`/`⟨,⟩`/`Sum.inl`/`.casesOn` terms |
| **Non-inhabitation verdicts** | "Proof-backed non-inhabitation result... when formula translation is complete" (library-api.md) | For *opaque* type variables, LJT failure means **no closed term exists at that polymorphic type** — a trustworthy negative answer no Lean tactic currently gives (`exact?` failing proves nothing) |
| **Exference engine** | Best-first search over an *inventory* of typed constants with per-name ratings (`environment/*.ratings`), explicit step/queue/depth budgets, ranked candidate batches | The implemented phase-3 slice discovers a bounded inventory from the live Lean environment, prioritizes exact-result session and public declarations, demotes conventional implementation workers without filtering them, gives later providers increasing penalties, and reuses successful inventories through a bounded generation-aware semantic cache; a persistent Mathlib-scale index, transitive relevance, and user-maintained ratings remain future work |
| **Shared synthesis foundation** | Parser-independent vocabulary (`Name`, `Type`, `Constraint`, `Environment → Inventory → PreparedInventory → QueryResult (SearchBatch Candidate) → Expression`), each arrow a checked boundary | The template for Leant's internal engine boundary: one fragment grammar, one candidate term grammar, one verification protocol, with the engine behind it swappable. **Scope decision: this feature is Haskell-only** — the Haskell implementation links Djex in-process; the Python edition does not grow a synthesis host |
| **Verification posture** | Engines are explicit about semantics ("neither backend guesses the other's"); truncated batches are labeled; a finished heuristic batch with no candidates "is not a proof of non-inhabitation" | Leant goes one better: **every candidate is elaborated by the Lean backend before display** (`example : (T) := term`), so the synthesizer never needs to be trusted — the same outsource-soundness pattern `:search?` and prove mode already use |
| **Embeddable library** | `build-depends: djex`, GHC 9.12.4, sealed session + checked request + result envelope; also three CLIs (`djex djinn --render expression "a -> a"`) | Leant is built with **the same GHC 9.12.4** — it links Djex directly as a library, in-process, with no subprocess or protocol overhead |
| **Shared REPL conventions** | Explicit backend selection (`djinn`/`exference`/`both`), settable limits, environment files | `:synth` command options: engine choice, candidate count, budget — consistent with Leant's `:set`-style toggles |

## 1.5 The post-merger scope: what Djex implements today

The current engines go beyond propositional LJT and monomorphic
best-first search. From the commit history (`a069029` through `6d6ff475`)
and the reports `2026-07-28-rank-n-inference-review.md`,
`2026-07-29-hypothesis-instantiation.md`, and
`2026-07-31-pairwise-rank-n-frontiers.md`:

- **Alpha-aware opaque atoms as the default boundary.** Quantified
  subterms are carried as alpha-normalized `TypeAtom`s with lexical
  scoping; ordinary unification never decomposes an atom. Everything
  below is a *bounded relaxation* of that default.
- **Positive rank-N opening (Djinn).** Goal-position `forall`s open into
  occurrence-scoped skolems via a polarized translation (arrow domains
  reverse polarity; products/sums preserve it). Search runs a *plan
  family*: the fully-opened and fully-opaque plans, the historical two
  singleton occurrence frontiers, and a deterministic pair-opaque and
  pair-open tail. Nested selections open the union of their required
  ancestor chains. The family grows quadratically and is exhaustive for
  five independent quantified sites without enumerating a power set;
  the central three-open/three-opaque layer at six sites is the next
  deliberate, documented gap.
- **Bounded hypothesis-side instantiation (Djinn).** A quantified
  hypothesis generates bounded premise axioms
  `Opaque(∀ as. t) → t[as := ss]` whose instantiation candidates are
  *only types the sequent itself supplies*: goal free variables, opened
  skolems, premise scopes, and quantified atoms already mentioned. That
  last class is **guarded impredicativity** — a binder may be solved
  with a polytype, but only one the query supplied. A worklist follows
  strictly shallower exposed foralls under per-scheme and global caps;
  chains beyond three binders stay opaque. This closes goals like
  `(forall a. a -> a) -> b -> b` and polymorphic transport through a
  container while remaining terminating.
- **Guarded impredicative provider subsumption (Exference).** A
  provider such as `forall a. a -> a` forwards to an impredicative
  requested scheme; the Quick-Look-style guard admits a quantified
  instantiation image only if it occurs, up to alpha equivalence, as a
  quantified subtree of the requested scheme: "no quantifier the query
  did not supply is ever invented". Scoped providers instantiate their
  complete leading forall chain freshly per use; provider contexts
  become proof obligations.
- **Bounded recursive deconstruction (Exference).** Recursive datatype
  declarations remain available to search, but matching stops after one
  constructor layer. Recursive fields enter that branch as ordinary
  providers and are not eagerly deconstructed again. This admits useful
  finite case terms without turning the engine into a recursion or
  induction synthesizer.
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

Djex continues expanding in this direction (a goal-side
forall-introduction slice is designed and documented as pending), which
strengthens the case for consuming it as a library behind a narrow
boundary: improvements arrive by version bump.

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
  bounded instantiation rule. Djex's deterministic singleton and
  pairwise frontiers transfer as a quadratic search-space cap that is
  exhaustive through five independent sites without becoming a power
  set.
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
  instance resolution (givens, superclasses, instances). In Lean,
  instance-implicit binders `[Monad m]` in a goal become ordinary
  opaque hypotheses for the engine (Djinn's dictionary-independent
  posture), and any candidate that *uses* a class method simply leaves
  the instance argument implicit — Lean's elaborator, running during
  verification, is a better evidence resolver than anything we would
  port.

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
| `tauto` / `itauto` (Mathlib) | Decides propositional goals (`itauto` is intuitionistic-complete) | `Prop`-only tactics; need Mathlib imported (minutes on this machine); no term display culture, no negative verdicts, nothing for `Type` |
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
 Optional live-provider inventory (Exference only; bounded to 80;
                                   semantic 12-entry LRU)
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
   Haskell-only: the engine lives in the Haskell implementation as a
   direct Djex library dependency; `leant.py` deliberately does not
   implement this feature.

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
  (polarity- and atom-aware) and to verdict labeling (§2.0). The
  Python REPL's `:synth` prints a pointer to the Haskell implementation
  rather than growing its own host.
- **Phase 2 — local inductives (M/L, implemented).** Treat
  non-recursive, non-dependent inductives and structures as generalized
  sums of products: constructors as right-rules, `casesOn` as
  left-rules — precisely how Djinn admits Haskell `data` declarations.
  As built, the serializer expands any qualifying inductive occurrence
  (non-recursive, non-indexed, non-mutual, fully parameter-applied,
  explicit non-dependent constructor fields — the check runs on the
  *instantiated* constructor telescope, so a `Sigma` whose second
  component ignores the first qualifies too) into its constructor list;
  the engine declares one fresh datatype per alpha-normalized occurrence
  key, parameterized over the goal variables its fields mention, and the
  renderer maps the engine's constructor spellings back to the Lean
  names. This covers built-ins (`Bool`, `Option`, `Ordering`, `Except`,
  `Decidable`) and session-declared types alike — no `:browse`
  machinery was needed; the instantiated-telescope route is simpler and
  stronger than fetching polymorphic constructor signatures. Refutations
  over expanded inductives remain sound: the engine sees the complete
  constructor list, and Lean's elimination restrictions only make Lean
  *more* restrictive than the engine's model, never less.
- **Phase 3 — ranked environment search (L, bounded first slice
  implemented).** Before an Exference query, a Lean metaprogram scans
  environment names cheaply and retains declarations whose root
  namespace occurs in the target, plus exact declarations made in the
  current session. It rejects generated names, orders exact-result
  session hits first, then exact-result public declarations, then the
  session and public fallback pools, and serializes at most 80 provider
  candidates. Conventional implementation-worker names (`TR`, `Impl`,
  `Aux`, `.go`, and `.loop`) remain eligible after those public tiers;
  exact session declarations bypass the heuristic. Providers outside the
  supported fragment are dropped individually before search. Leant gives
  the survivors private collision-free engine names, maps them back to the exact
  fully-qualified Lean globals during rendering, and assigns increasing
  positive rating penalties in discovery order so fallback constants do
  not drown the best match. Search remains subject to its explicit
  budgets (`:set synth-steps` exposes the step bound; queue/depth retain
  conservative engine defaults) and reports truncation honestly. This is
  enough for `(α → β) → List α → List β` to prefer
  `List.map`.

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
  persistent Mathlib-scale index, transitive relevance across unrelated
  namespaces, and user/core/Mathlib ratings are still future work.

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
  beyond it (including instantiation chains longer than three binders
  and the six-site three-open/three-opaque plan gap) the answer is "no term
  found within bounds" — full impredicative inhabitation is undecidable,
  so this boundary is permanent, and the display must never upgrade it
  to a refutation.
- **Recursive elimination is bounded to one layer in Exference.** A
  recursive field exposed by a constructor match is available as a
  normal branch-local value, but is not eagerly decomposed again. The
  engine may reuse a library provider for the recursive continuation;
  it does not invent a recursive definition, induction, or unbounded
  eliminator. Djinn remains closed and deciding: recursive types are
  opaque there, with constructors only as premises/introduction rules.
- **Parametricity caveat**: "uninhabited" verdicts are about *closed
  terms at the polymorphic type* — `∀ α β, α → β` being uninhabited does
  not mean a particular instantiation is empty. The display must say
  "no closed term of this polymorphic type exists", never "this is
  false"; in `Prop` the verdict must further note it is about
  *constructive* provability (Peirce's law is classically fine).
- **Performance**: LJT on interactive-size goals is microseconds; the
  cost center is the backend verification round-trip (~100–300 ms per
  candidate on this machine), so batches should verify lazily, top
  candidate first. The live inventory is capped at 80 serialized
  providers. Its bounded semantic LRU avoids repeated discovery for the
  same canonical roots/result head and provider world, while suffix-only
  history replay avoids rebuilding the synthesis environment after each
  generated result. Root-namespace relevance is intentionally shallow;
  a persistent Mathlib-scale relevance index remains open work.
- **Maintenance**: embedding Djex ties Leant to a large local
  package (and to its GHC version). Mitigation: the narrow engine
  boundary keeps Djex swappable for a small purpose-built LJT module
  later, without REPL-layer changes.
- **Haskell-only**: Python Leant users must switch binaries for this
  feature — an accepted asymmetry (see §2.3); the two implementations
  now have distinct strengths instead of being mirrors.

## 6. Recommendation

The review of Djex's current scope strengthens the original
recommendation: the engine now handles bounded rank-N and guarded
impredicative goals out of the box, and the analysis in §2.0 shows the
expensive parts of that machinery are either native to Lean or absorbed
by kernel-side verification — Leant's share of the work shrank while the
reachable goal space grew.

Phases 0–2 have delivered instant verified lambda terms, trustworthy
uninhabitation answers, inductive-data support, and a prove-mode step
that composes rather than merely searches. The bounded phase-3 slice
now validates the live-environment design without committing Leant to a
global Mathlib index: exact globals survive the engine round-trip,
ordered penalties keep an 80-provider query useful, and one-layer
recursive elimination composes with library reuse. A bounded semantic
LRU now removes repeated inventory round-trips without changing startup
discipline, and synthesis-history appends replay only their suffix. The
next phase-3 work should measure those latency gains, improve relevance
beyond a single target root, and expose stable user ratings.

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
first half; deliver the second. When the engine soundly refutes a
`Prop` goal whose fragment is purely propositional (no quantifiers),
re-run it once on `¬¬goal`. By Glivenko's theorem this succeeds
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

### D. Constructors of recursive inductives as premises — M (implemented)

Phase 2 leaves `Nat`, `List`, and friends as opaque atoms, so
`:synth (∀ a, a → List a)` answers "no term found within bounds".
For Djinn, the *constructors* of a recursive inductive are sound
introduction rules without opening elimination: declare the atom's key
as an abstract type and add `List.nil : K`,
`List.cons : v → K → K` as value premises (fields translate through
the existing fragment translation; recursive occurrences map to the
atom's variable; constructors with out-of-fragment fields are simply
omitted). Refutation soundness is unaffected — such goals already carry
unsafe atoms, so negative verdicts are already downgraded. Only
constructors of inductives that actually occur in the goal are
declared, keeping the per-query environment small. The later Exference
slice replaces this projection with a real nominal recursive datatype
and its bounded one-layer eliminator; Djinn's behavior is unchanged.

### E. Rendering polish: anonymous constructors first — S, cosmetic (implemented)

Candidates over single-constructor structures render as
`Pair.mk a b` and `match p with | Pair.mk b _ => b`; Lean idiom is
`⟨a, b⟩` and `p.fst` (or at least `⟨b, _⟩` patterns). Offer the
anonymous-constructor spelling as the first textual variant (the
existing variant machinery plus verification already handles
preference order), and short-dot constructor names (`.some x`) where
the expected type is known. Pure renderer work; every variant is
still backend-verified.

### F. Exference and bounded live providers — L, phase-3 slice (implemented)

Djex's Exference adapter sits behind the existing
`Leant.Synth.Engine` boundary, selectable via `:set synth-engine
djinn|exference|both`; `:set synth-steps` exposes Exference's step
budget while queue/depth retain conservative engine defaults. Its
structural inventory contains datatype declarations and
hypothesis premises. The implemented extension now adds up to 80
providers from the live Lean environment: target-root and exact-session
filtering bounds discovery, result-head/short-name ordering supplies a
relevance signal, increasing positive penalties preserve that signal
during search, and a private-name map restores the exact Lean global in
the rendered term. Providers that fall outside the fragment are dropped
individually, and Lean verification remains the final authority. The
serializer derives a stable query from sorted, deduplicated target roots
and its result head; successful inventories (including empty ones) live
in a generation-aware 12-entry LRU. Provider-affecting environment
changes invalidate that generation, while generated `itN` results do
not. Session-history appends likewise replay only their new suffix into
the cached synthesis environment.

For complete constructor inventories whose applied parameters can be
represented safely, the Exference projection also models recursive
inductives nominally and enables one finite constructor match, with
recursive fields retained as ordinary local values rather than
recursively eliminated. Together,
these changes let Exference discover both bounded structural case terms
and library reuse such as `List.map`. `both` mode still keeps Djinn's
closed, deciding projection separate, so importing a heuristic
inventory cannot weaken its refutation semantics.

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
