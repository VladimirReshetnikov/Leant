# Leant — a Djex-based synthesis REPL for Lean 4

Leant brings [Djex](https://github.com/VladimirReshetnikov/Djex)-powered program and proof synthesis to
Lean 4, wrapped in an interactive read-eval-print loop. The centerpiece
is `:synth`: give it a type and it constructs terms of that type —
ranked, bound into the session, and every candidate re-elaborated by
Lean before you see it — or proves that no such term exists. Around the
synthesizer, Leant is a full REPL in the GHCi-inspired mold Djex itself
follows: type expressions and they are evaluated, type declarations and
they enter the session, and a family of `:commands` gives you type
queries, documentation, search, and interactive tactic proving.

```text
λ> 2 + 2
4
λ> def double (n : Nat) : Nat := n + n
λ> double 21
42
λ> :synth ((A → B → C) → (A → B) → A → C)
  it1  fun f g x => f x (g x)
λ> :synth (∀ a b : Type, a → b)
provably uninhabited — no closed term of this polymorphic type exists
```

Lean 4 is normally driven from an editor, where the language server
shows goals and diagnostics as you edit a file. Leant complements that
workflow with a conversational one, aimed at exploration — trying a
lemma, poking at a definition, asking *is this type even inhabited?* —
where the unit of work is a line, not a file.

**Leant is experimental and under active development.** Commands change
shape between commits and output formats are not stable.

There is a manual: **[docs/Leant_Overview/Leant_Overview.pdf](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Leant_Overview/Leant_Overview.pdf)**
— an overview and tutorial, with a detailed tour of `:synth`
([LaTeX source](docs/Leant_Overview/Leant_Overview.tex)).

## Contents

- [Highlights](#highlights)
- [Getting started](#getting-started)
- [Usage](#usage) — command-line options and the command table
- [Interactive proving — `:prove`](#interactive-proving--prove)
- [`:synth` — automatic term synthesis](#synth--automatic-term-synthesis)
  - [Higher-order plumbing](#higher-order-plumbing)
  - [Programs you already know](#programs-you-already-know)
  - [Rank-N and impredicative goals](#rank-n-and-impredicative-goals)
  - [Impossibility, proved](#impossibility-proved)
  - [Classical candidates](#classical-candidates)
  - [Inductive types](#inductive-types)
  - [Recursion from the library](#recursion-from-the-library)
  - [Dependent formulas as cargo](#dependent-formulas-as-cargo)
  - [Synthesis inside a proof](#synthesis-inside-a-proof)
  - [Engines, budgets, and the fine print](#engines-budgets-and-the-fine-print)
- [How it works](#how-it-works)
- [Development](#development)
- [License](#license)

Companion documents:

- the **[manual](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Leant_Overview/Leant_Overview.pdf)** — tutorial and `:synth` tour;
- **[docs/length-ranking.md](docs/length-ranking.md)** — the complete
  Length counterexample-ranking and replay-authorized filtering reference;
- **[docs/synth-internals.md](docs/synth-internals.md)** — the design
  boundaries and dated-report index behind `:synth`;
- **[Lean from First Principles](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Lean_from_First_Principles/Lean_from_First_Principles.pdf)**
  — a beginner's path from "a term has a type" to verified type-directed
  synthesis: reading Lean syntax, propositions as types, dependent
  functions and pairs, universes, definitional equality, inductive types,
  and the Calculus of Constructions; how Lean elaborates surface syntax
  into kernel terms and what the kernel trusts; and then Leant and Djex
  end to end — the smaller synthesis type world, the fragment
  translation, the two search engines, rendering, verification, negative
  evidence, and worked traces
  ([LaTeX source](docs/Lean_from_First_Principles/Lean_from_First_Principles.tex));
- **[Z3 from First Principles](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Z3_for_Leant_and_Djex/Z3_for_Leant_and_Djex.pdf)**
  — a beginner's guide to Z3 for this codebase, assuming no logic
  background: what satisfiability, models, and `unsat` mean, SMT-LIB from
  syntax to models, cores, and Horn clauses, why a solver boundary needs
  fingerprints, process ownership, and replay, and then a module-by-module
  trace of how the current Length domain and Leant's rank and filter modes
  actually use Z3, plus a reading and troubleshooting guide
  ([LaTeX source](docs/Z3_for_Leant_and_Djex/Z3_for_Leant_and_Djex.tex));
- the **[Z3 behavioral synthesis proposal](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.pdf)**
  — where the behavioral layer goes next: counterexample-guided search,
  typed sketch completion, semantic pruning, and Lean-checked proof
  artifacts ([LaTeX source](docs/Z3_Behavioral_Synthesis_Proposal/Z3_Behavioral_Synthesis_Proposal.tex));
- the **[codebase walkthrough](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.pdf)**
  — the maintainer's tour of both repositories against a pinned pair of
  revisions: the build graph, Djex's opaque authority types, Djinn's
  proof-producing search, Exference's typed-hole search and independent
  checker, and Leant's backend protocol, translation, rendering, and
  verification, with end-to-end traces and change recipes
  ([LaTeX source](docs/Djex_Leant_Codebase_Walkthrough/Djex_Leant_Codebase_Walkthrough.tex));
- the **[Lean 4 rewrite analysis](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Leant_Djex_Lean4_Rewrite_Analysis/Leant_Djex_Lean4_Rewrite_Analysis.pdf)**
  — a feasibility study of reimplementing Leant and Djex in Lean itself:
  which of today's boundaries would survive, what a Lean host makes
  simpler (elaborated goals staying `Expr`, kernel-checked candidates
  without pretty-printed text as authority), and a recommended end state
  and migration path ([LaTeX source](docs/Leant_Djex_Lean4_Rewrite_Analysis/Leant_Djex_Lean4_Rewrite_Analysis.tex)).

## Highlights

- **Verified term synthesis.** `:synth TYPE` constructs programs and
  proofs — ranked, bound as `it1`, `it2`, …, and every candidate
  re-elaborated by the Lean backend before it is shown. When no
  constructive inhabitant exists it can *prove* that, and for refuted
  propositional goals it offers classical candidates instead.
- **Interactive proving.** `:prove` turns the prompt into a
  tactic-by-tactic loop with unlimited `:undo`, and `:qed` saves the
  finished proof as a real theorem in the session.
- **A real REPL.** Definitions persist via the backend's environment
  threading; `it` holds the last result; TAB completes `:commands` and
  dotted identifiers; multi-line input opens automatically on
  syntactically incomplete lines and a blank line submits (`:{` … `:}`
  delimits an explicit block, as in GHCi).
- **Crash-proof sessions.** If the backend dies, times out, or is
  interrupted, it restarts and the session (imports + history) replays
  automatically; prove-mode scripts are printed before the mode exits,
  so work is never lost.
- **Sessions as artifacts.** `:transcript` records everything;
  `:pickle`/`:unpickle` snapshot and restore environments as `.olean`.
  Leant-created snapshots also carry a fingerprinted synthesis companion,
  while ordinary upstream snapshots remain compatible;
  `:load`/`:reload` round-trip `.lean` files.

## Getting started

Requires [GHC](https://www.haskell.org/ghcup/) 9.12.4 and cabal, plus
`lake`/`lean` on PATH (via [elan](https://github.com/leanprover/elan)).

```bash
git clone --recurse-submodules https://github.com/VladimirReshetnikov/Leant
cd Leant
cabal build exe:leant
```

The REPL core uses GHC boot libraries only, but `:synth` links the
vendored [Djex](lib/Djex) synthesis library (a read-only git submodule —
if you cloned without `--recurse-submodules`, run
`git submodule update --init lib/Djex`), which pulls `haskell-src-exts`
and a few other packages from Hackage. The bundled `cabal.project`
builds both packages together. On Windows, `leant.cmd` builds on first
use and runs the binary.

Leant drives the community
[leanprover-community/repl](https://github.com/leanprover-community/repl)
backend. It finds an existing `repl` binary automatically (including one
built by [LeanInteract](https://github.com/augustepoiroux/LeanInteract),
whose cache it searches), or you can point it at any build matching your
project's toolchain with `--repl-exe PATH` or the `LEANT_BACKEND`
environment variable.

## Usage

```text
leant [FILE] [-p|--project DIR] [--plain] [-i|--import MOD] [--help]
      [--timeout N] [--time] [--transcript [FILE]] [--timestamps]
      [--repl-exe PATH] [--lake PATH]
      [--length-ranking-config ABSOLUTE-PATH]
      [--length-ranking-config-timeout MS]
      [--length-ranking-allow-unpinned]
```

Run inside a Lake project (auto-detected, or `--project DIR`) to make
the project's modules and dependencies importable, or `--plain` for a
bare stdlib session with subsecond startup. Expressions evaluate via
`#eval` with `#check` fallback; declarations (`def`, `theorem`,
`inductive`, `open`, …) run verbatim and, on success, advance the
session environment; `#`-commands pass straight through.

**Length behavioral assessment** is an optional last stage that asks Z3
about candidates Lean has already verified. It is off unless the session
started with `--length-ranking-config`, which activates one startup policy
and one scalar-or-pair contract. Once active:

- plain `:synth TYPE` (and `--behavior-mode rank`) keeps the usual stable
  ranking, moving only candidates with a replayed counterexample after the
  rest, never dropping any;
- `:synth --behavior-mode filter -- TYPE` additionally *omits* candidates that
  Z3 refuted against the activated contract — and only those: a raw `sat`,
  `unsat`, or `unknown`, an unassessed input, or a positive bounded-evidence
  receipt never causes a rejection;
- `--length-contract ABSOLUTE-PATH` swaps in a passive contract for one
  command;
- an inline constraint can instead select one of the two fixed exact-case
  `List` profiles, declare the observed physical source-arrow arguments, and
  write one bounded ASCII Length relation directly:

  ```text
  :synth --behavior-mode filter --length-model list-scalar-exact-cases --length-inputs arg0 --where len(result)=len(arg0)+min(len(arg0),1) -- List Nat -> List Nat
  :synth --behavior-mode filter --length-model list-binary-product-exact-cases --length-inputs arg0 --where len(result.first)+len(result.second)=2*len(arg0) -- List Nat -> Prod (List Nat) (List Nat)
  ```

  The clause is unquoted and ends at the standalone `--`. Inline constraints
  require literal `filter`, are mutually exclusive with `--length-contract`,
  and reuse the already activated startup execution policy; they cannot
  activate Z3 or introduce provider laws.

A filter command works through one lazy engine result in at most two batches
of `:set synth-verify` groups (twice that for `both`), reusing one
command-local counterexample bank across every lane of that command, and
stops at the first batch with a survivor; at most `:set synth-shown`
survivors are shown and bound, every rejection stays visible, and nothing
from the assessment enters `ReplState`, history, or snapshots. Any adapter or
solver failure preserves the complete verified batch instead of guessing. The
batch schedule, deadlines, rejection taxonomy, schemas, and presentation are
specified in [docs/length-ranking.md](docs/length-ranking.md); the Main
landing is recorded in the
[inline Length where-clause runtime report](docs/reports/2026-08-20-inline-length-where-runtime.md).

Applicable-domain ranking has one current recursive piecewise-affine
algorithm: library callers use
`enableLengthRankingApplicableDomainValidation`, receive
`ApplicableDomainEstablished` or `LengthSpinePairApplicableDomainEstablished`,
and render with `renderLengthApplicableDomainValidationNote` or its
`SpinePair` sibling. The former stage-specific builders, receipts, and
renderers were deleted without aliases (Leant promises no API or output
compatibility); the versionless startup and contract-only schemas, including
the seven numeric members of `applicableDomainValidation`, did not change.
See the
[current applicable-domain policy report](docs/reports/2026-08-15-current-length-applicable-domain-policy.md).

| Command | Meaning |
|---|---|
| `:help`, `:h`, `:?` | show help |
| `:quit`, `:q` | exit |
| `:type EXPR`, `:t` | show the type of an expression (`#check`) |
| `:info NAME`, `:i` | show a definition (`#print`, rendered as a valid declaration) |
| `:load FILE`, `:l` | reset the session and load a `.lean` file |
| `:reload`, `:r` | reload the last loaded file |
| `:import MOD` | add an import (rebuilds and replays history; rejected over an opaque snapshot) |
| `:imports` | list active imports, or the imports restored by the next `:reset` |
| `:browse [NS]` | list declarations in a namespace (`:browse!` includes generated auxiliaries) |
| `:doc NAME` | show the documentation string of a declaration |
| `:search TEXT` | case-insensitive name search over the environment |
| `:search? TYPE` | proof search: what proves TYPE? (via `exact?`) |
| `:synth TYPE` | verified term synthesis (see below) |
| `:synth --behavior-mode rank\|filter -- TYPE` | explicitly choose the operation; disabled `rank` is identity, while `filter` requires an activated startup Length policy |
| `:synth [--behavior-mode rank\|filter] --length-contract ABSOLUTE-PATH -- TYPE` | use one passive scalar-or-pair Length contract for this command; omitted mode means `rank` |
| `:synth --behavior-mode filter --length-model list-scalar-exact-cases\|list-binary-product-exact-cases --length-inputs arg0[,argN...] --where CLAUSE -- TYPE` | use one inline, unquoted, bounded Length postcondition with explicit list model and observed physical arguments; requires the activated startup policy |
| `:prove [PROP]` | interactive prove mode; bare form resumes the last `sorry` |
| `:set OPT VAL` | `set_option` persisting in the session |
| `:undo` | revert the last state-changing command |
| `:reset` | clear definitions or an active snapshot base, keeping configured imports |
| `:history` | list state-changing commands after the current import/snapshot base |
| `:env` | show the backend environment id |
| `:time` | toggle per-command timing |
| `:transcript [FILE\|on\|off]` | record a full transcript of the session |
| `:timestamps [on\|off]` | timestamp each command in the transcript |
| `:pickle FILE` / `:unpickle FILE` | save the environment plus synthesis companion / restore it as a new undo base |
| `:! CMD` | run a shell command |

Built-ins and keywords that are not constants in the environment
(`imax`, `Sort`, `fun`, `→`, `∀`, `⟨⟩`, …) get explanatory help from
`:t`/`:info` instead of an unhelpful "Unknown identifier".

## Interactive proving — `:prove`

`:prove PROP` opens a tactic loop against the backend's proof-state
protocol (bare `:prove` resumes the most recent `sorry`). Every line is
a tactic; goals reprint after each one, followed by a Lean-verified
suggestion for the next tactic. The candidate probes are shaped by the
goal and its hypotheses: an `intro` suggestion names the binders it
would introduce, a disjunction goal is probed with `left`/`right`, a
hypothesis whose type a single step can take apart is probed with
`cases h` or `obtain ⟨x, h1⟩ := h`, and a data-typed variable the goal
mentions is probed with `induction`. The search prefers a candidate that
closes the goal outright and annotates the suggestion accordingly
(`closes the goal`, `splits into 2 goals`); when no single tactic
closes it, a second phase chains quick finishers onto the best
progressing candidates (`constructor <;> omega`, `obtain ⟨h, h2⟩ := h1
<;> exact Exists.intro x h`), so even the opening suggestion is often a
complete checked proof. The chains also try `simp_all`, unfolding the
definitions the goal mentions and calling in `omega` on whatever
arithmetic remains, which is how an induction suggestion can arrive as
a finished proof: `induction l <;> simp_all [myLen]`, or `induction n
<;> simp_all [double] <;> omega`. Suggestions are advisory: they never advance
the proof or enter the script, and `:suggest` reprints the cached
suggestion.
`:undo` takes back steps without limit; `:script` shows the accumulated proof;
`:auto` tries common finishers; `:qed [NAME]` turns the script into a real
theorem in the session. `?`-tactics (`exact?`, `simp?`, `rw?`) record the
tactic they *found* rather than the question-mark form. Proof-state identifiers
belong to one backend process: if that process stops, Leant leaves prove mode
and prints the accumulated script instead of submitting a stale identifier
after the session restarts.

```text
λ> :prove ∀ p q : Prop, p ∧ q → q ∧ p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p q : Prop), p ∧ q → q ∧ p
suggestion: intro p q h <;> exact And.comm.mp h  (closes the goal)
⊢> intro p q h
p q : Prop
h : p ∧ q
⊢ q ∧ p
suggestion: exact And.comm.mp h  (closes the goal)
⊢> exact And.comm.mp h
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed and_swap
saved: theorem and_swap : ∀ p q : Prop, p ∧ q → q ∧ p
```

At its best the suggestion machinery hands you a finished induction:
here it combines `induction` (the goal mentions a data-typed
variable), `simp_all` unfolding the function the goal is about, and
`omega` for the leftover arithmetic — a complete verified proof of a
theorem about a function defined two lines earlier:

```text
λ> def double : Nat → Nat
…>   | 0 => 0
…>   | n + 1 => double n + 2
…>
λ> :prove ∀ n : Nat, double n = 2 * n
entering prove mode — type tactics; :help for commands
⊢ ∀ (n : Nat), double n = 2 * n
suggestion: intro n
⊢> intro n
n : Nat
⊢ double n = 2 * n
suggestion: induction n <;> simp_all [double] <;> omega  (closes the goal)
⊢> induction n <;> simp_all [double] <;> omega
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed double_two_mul
saved: theorem double_two_mul : ∀ n : Nat, double n = 2 * n
```

## `:synth` — automatic term synthesis

`:synth TYPE` answers the question *"write me a term of this type"* —
read through propositions-as-types, *"prove this"* — and sometimes the
stronger question *"show me that no such term exists."*

**What it can take.** The core fragment is the structural connectives
`→ / × / ∧ / ⊕ / ∨ / ↔ / ¬ / ⊥ / ⊤ / ∀` over opaque variables. On top of
that:

- *Inductive types* whose constructors can be represented structurally —
  built-ins such as `Option`, `Except`, and `List`, and your own
  `inductive`/`structure` declarations. Non-recursive families get their
  constructors and case analysis; recursive families get their
  constructors plus one layer of case analysis. Occurrences of the same
  family at different type arguments are recognized as one family across
  the whole goal.
- *Rank-N and impredicative quantification*, within explicit bounds
  ([below](#rank-n-and-impredicative-goals)).
- *A slice of your live environment*: both engines can pull in a small,
  goal-relevant set of session and library declarations, and `List`/`Nat`
  goals can compose rated library functions such as `List.map` and
  `List.foldr` into candidates ([below](#recursion-from-the-library)).

The design and its phasing are in
[docs/SYNTHESIS_PROPOSAL.md](docs/SYNTHESIS_PROPOSAL.md); the internal
boundaries — how the goal is translated, how providers are bound, and
which dated report pins each invariant — are in
[docs/synth-internals.md](docs/synth-internals.md).

Three rules run through the design:

- **The engine is never trusted.** Every candidate is re-elaborated by
  the Lean backend against the exact goal (`example : (T) := term`)
  before you see it. An engine bug costs a dropped candidate, never a
  wrong answer.
- **Refusals come with reasons.** A goal outside the fragment is turned
  away with a note saying what fell outside, not quietly mangled into
  something answerable.
- **Negative verdicts are labeled by strength.** "Provably uninhabited"
  appears only when the translation was complete and lossless; anything
  weaker is reported as "no term found within bounds," which claims
  nothing.

Transcripts below are lightly abridged: `⋯` marks elided trailing
candidates (and, where applicable, a truncation note).

### Higher-order plumbing

The sweet spot is the "plumbing" terms one writes constantly. Free
capital identifiers are auto-bound, so quick queries stay quick, and
the first candidate is reliably the term you would have written —
here `flip`, composition, `uncurry`, and product associativity:

```text
λ> :synth ((a → b → c) → b → a → c)
  it1  fun f x y => f y x
λ> :synth ((b → c) → (a → b) → a → c)
  it1  fun f g x => f (g x)
λ> :synth ((A → B → C) → A × B → C)
  it1  fun f ⟨x, y⟩ => f x y
λ> :synth (((A × B) × C) → A × (B × C))
  it1  fun ⟨⟨x, y⟩, z⟩ => ⟨x, ⟨y, z⟩⟩
```

Candidates are ranked smallest-first and *bound into the session* as
`it1`, `it2`, …, with bare `it` the best one — they are ordinary
definitions, so you can evaluate them immediately:

```text
λ> :synth (a → a → a)
  it1  fun _ x => x
  it2  fun x _ => x
λ> #eval it2 "left" "right"
"left"
```

Read through propositions-as-types, the same plumbing proves logical
identities, and the proof terms *are* the plumbing: `Iff` symmetry is
a swap, `¬(p ∧ q) ↔ (p → ¬q)` is currying, and De Morgan's law packs
one direction each into an anonymous constructor:

```text
λ> :synth (∀ p q : Prop, (p ↔ q) → (q ↔ p))
  it1  fun _ _ ⟨f, g⟩ => ⟨g, f⟩
λ> :synth (∀ p q : Prop, ¬(p ∧ q) ↔ (p → ¬q))
  it1  fun _ _ => ⟨fun k x y => k ⟨x, y⟩, fun k1 ⟨z, w⟩ => k1 z w⟩
λ> :synth (∀ p q : Prop, ¬(p ∨ q) ↔ ¬p ∧ ¬q)
  it1  fun _ _ => ⟨fun k => ⟨fun x => k (.inl x), fun y => k (.inr y)⟩, fun ⟨k1, k2⟩ z => match z with | .inl w => k1 w | .inr x1 => k2 x1⟩
```

It reaches the textbook curiosities too — `(p ↔ ¬p) → False` comes
out by the classic self-application trick:

```text
λ> :synth (∀ p : Prop, (p ↔ ¬p) → False)
  it1  fun _ ⟨k, f⟩ => k (f (fun x => k x x)) (f (fun y => k y y))
```

Binders are named by role — functions `f g h`, values `x y z`,
negations and continuations `k` — which keeps large candidates
readable.

### Programs you already know

Some types have one sensible inhabitant, and asking for it by type is
quicker than remembering which library corner it lives in. The binds
of the reader and state monads:

```text
λ> :synth ((S → A) → (A → S → B) → S → B)
  it1  fun f g x => g (f x) x
λ> :synth ((S → A × S) → (A → S → B × S) → S → B × S)
  it1  fun f g x => match f x with | ⟨y, z⟩ => g y z
  it2  fun f g x => match f x with | ⟨y, _⟩ => g y x
  ⋯
```

For the state monad, `it1` threads the state correctly, while `it2`
is type-correct and runs `g` on the *initial* state — the classic
state-threading bug, which the type admits just as happily. Types alone
cannot tell these apart, which is why all candidates are shown and each
is one keystroke from a test run. With inductive expansion (below) the
same game extends to data — `Option.bind`, with the lazy `.none`
candidate ranked first and the real one second:

```text
λ> :synth (∀ a b : Type, Option a → (a → Option b) → Option b)
  it1  fun _ _ _ _ => .none
  it2  fun _ _ x f => match x with | .none => (.none) | .some y => f y
```

### Rank-N and impredicative goals

A polymorphic hypothesis is not just cargo: Djex instantiates it at
types the goal itself supplies — including, under a guard, at
*polymorphic* ones. Here the first candidate applies the identity
hypothesis to the whole goal `Q → Q`, an impredicative instantiation:

```text
λ> :synth ((∀ p : Prop, p → p) → Q → Q)
  it1  fun f => f _
  it2  fun _ x => x
```

A vacuous local provider can retain that closed quantified choice explicitly.
This matters when its result is an opaque Lean type: Leant keeps the result as
an ambient query parameter, while Djex supplies only the type argument already
present in the goal. Both engines now reach the application, and backend
verification selects the `Type _` universe hint needed by Lean's positional
`@` syntax:

```text
λ> axiom Demo.Token : Type
λ> :synth ((∀ x : Type, x → x) → ({a : Type 1} → Demo.Token) → Demo.Token)
  it1  fun _ x => @x (∀ (a0_0 : Type _), a0_0 → a0_0)
λ> :set synth-engine exference
synth engine: exference
λ> :synth ((∀ x : Type, x → x) → ({a : Type 1} → Demo.Token) → Demo.Token)
  it1  fun f x => f _ (@x (∀ (a0_0 : Type _), a0_0 → a0_0))
```

The search and rendering boundaries are recorded in the
[scoped quantified-provider report](docs/reports/2026-08-01-scoped-quantified-local-providers.md).

The bridge now preserves proper-type application spines too.  A bound
first-order constructor `F` stays a higher-kinded Djex variable, while an
opaque Lean family keeps one rigid nominal head across its occurrences.
That exposes the quantified argument to both engines without exposing the
family's implementation:

```text
λ> axiom Wrap : Type 1 → Type
λ> :synth ((∀ a : Type 1, Wrap a) → Wrap (∀ b : Type, b → b))
  it1  fun x => x _
λ> :set synth-engine exference
synth engine: exference
λ> :synth (∀ (F : Type 1 → Type), (∀ a : Type 1, F a) → F (∀ b : Type, b → b))
  it1  fun _ x => x _
```

The same transport now works without throwing away datatype structure.
`Option`, `Except`, and qualifying user inductives have complete constructor
schemas, while their exact Lean heads are shared across all proper-type
instantiations in one query. The provider-free engine tests exercise built-in
one- and two-parameter families through both engines. Standalone Exference now
tries an in-fragment goal without live providers first and asks Lean to verify
that baseline before it discovers an environment inventory. Djinn and `both`
now use the same provider-free ordering rule. The live golden
therefore exercises real `Option` through Exference as well as Djinn; separate
atomic and structural-miss controls confirm that a needed provider still wins
when the baseline is inapplicable, ends without a verified term, or soundly
refutes only the provider-free calculus:

```text
λ> inductive Demo.Phantom2 (a b : Type 1) : Type 1 where
…> | mk : Demo.Phantom2 a b
…>
λ> :set synth-engine exference
synth engine: exference
λ> :synth ((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
  it1  fun x => x _
λ> :synth ((∀ a b : Type 1, Demo.Phantom2 a b) → Demo.Phantom2 (∀ x : Type, x → x) (∀ y : Type, y → y))
  it1  fun x => x _ _
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth ((∀ a : Type 1, Option a) → Option (∀ b : Type, b → b))
  it1  fun x => x _
λ> :synth ((∀ a b : Type 1, Demo.Phantom2 a b) → Demo.Phantom2 (∀ x : Type, x → x) (∀ y : Type, y → y))
  it1  fun x => x _ _
```

Live polymorphic definitions now participate in Djinn's bounded
instantiation too. This ordinary Lean definition is discovered only after the
provider-free lane ends without a verified term (a bounded miss in this
example), then specialized independently at a closed built-in type, an opaque
session type, and a rank-N type:

```text
λ> def Demo.sealedBox {a : Type u} (value : a) : Demo.SealedBox a :=
…>   .mk value rfl
…>
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth (Nat → Demo.SealedBox Nat)
  it1  Demo.sealedBox
λ> :synth (Demo.Seed → Demo.SealedBox Demo.Seed)
  it1  Demo.sealedBox
λ> :synth ((∀ x : Type, x → x) → Demo.SealedBox (∀ x : Type, x → x))
  it1  Demo.sealedBox
```

Vacuous type choices are retained when Lean needs to see them. Here the class
argument lies between the chosen type and the result, so Leant names the type
binder and leaves dictionary reconstruction to Lean:

```text
λ> axiom Demo.Token : Type
λ> class Demo.C (a : Type) : Prop where witness : True
λ> instance : Demo.C Nat := ⟨True.intro⟩
λ> axiom Demo.global {a : Type} [Demo.C a] : Demo.Token
λ> :synth (Nat → Demo.Token)
  it1  fun _ => Demo.global («a» := Nat)
```

Closed, context-free quantified choices follow the same path instead of
collapsing to an inferred `_`. Djex keeps their binders alpha-safe, and Leant
gives them stable local names while rendering the provider's own binder
domain, so the expected universe stays visible in the printed argument:

```text
λ> class Demo.PolyC (a : Type 1) : Prop where witness : True
λ> instance : Demo.PolyC (∀ x : Type, x → x) := ⟨True.intro⟩
λ> axiom Demo.polyGlobal {a : Type 1} [Demo.PolyC a] : Demo.Token
λ> :synth ((∀ x : Type, x → x) → Demo.Token)
  it1  fun _ => Demo.polyGlobal («a» := (∀ (a0_0 : Type _), a0_0 → a0_0))
```

The choice need not occur in the query when Lean's active instance heads prove
it for that exact provider. Here the goal is only `Gap.Token`; discovery learns
the quantified argument by resolving `Gap.C ?a` against the active instance,
then both checked Djex runners retain the same explicit application:

```text
λ> axiom Gap.Token : Type
λ> class Gap.C (a : Type 1) : Prop where witness : True
λ> instance : Gap.C (∀ x : Type, x → x) := ⟨True.intro⟩
λ> axiom Gap.polyGlobal {a : Type 1} [Gap.C a] : Gap.Token
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth Gap.Token
  it1  Gap.polyGlobal («a» := (∀ (a0_0 : Type _), a0_0 → a0_0))
λ> :set synth-engine exference
synth engine: exference
λ> :synth Gap.Token
  it1  Gap.polyGlobal («a» := (∀ (a0_0 : Type _), a0_0 → a0_0))
λ> :set synth-engine both
synth engine: both
λ> :synth Gap.Token
  it1  Gap.polyGlobal («a» := (∀ (a0_0 : Type _), a0_0 → a0_0))
```

The instance may determine a higher-kinded binder which never occurs in the
provider body. Leant retains the argument's bounded `Type -> ... -> Type` kind
instead of collapsing it to proper type, so both checked engines preserve this
constraint-only specialization:

```text
λ> namespace Higher
λ> axiom Wrap : Type → Type
λ> class VacuousChoice (F : Type → Type) : Prop where witness : True
λ> instance : VacuousChoice Wrap := ⟨True.intro⟩
λ> axiom VacuousToken : Type
λ> axiom vacuous {F : Type → Type} [VacuousChoice F] : VacuousToken
λ> end Higher
λ> :set synth-engine djinn
synth engine: djinn
λ> :synth Higher.VacuousToken
  it1  Higher.vacuous («F» := Higher.Wrap)
λ> :set synth-engine exference
synth engine: exference
λ> :synth Higher.VacuousToken
  it1  Higher.vacuous («F» := Higher.Wrap)
```

The provider-assignment machinery behind these transcripts — how many
heads are inspected, how vectors are bounded and deduplicated, the wire
formats, and the exact-context (`FExactContext`) rules — is specified in
[docs/synth-internals.md](docs/synth-internals.md#provider-instantiation-evidence).

And a Church-encoded pair converts into a real conjunction — the
quantified hypothesis is instantiated once at `p` and once at `q`, fed
the matching projection each time:

```text
λ> :synth (∀ p q : Prop, (∀ r : Prop, (p → q → r) → r) → p ∧ q)
  it1  fun _ _ f => ⟨f _ (fun x _ => x), f _ (fun _ y => y)⟩
  ⋯
```

Djinn now keeps three instantiation families distinct. The historical local
family specializes context-free hypotheses at query variables, opened
skolems, premise scopes, and guarded quantified shapes. A new final
query-closed tail additionally admits closed, forall-free subtrees already
present in the checked goal, but only for schemes embedded in that goal.
Loaded environment schemes remain a third family: they retain exact source
identity and may also use closed subtrees from loaded signatures.

That distinction makes the following provider-free Lean goal reachable without
pretending that <code>Mono</code> is a type variable:

~~~text
λ> axiom QueryClosed.Mono : Type
λ> axiom QueryClosed.Token : Type
λ> axiom QueryClosed.Indexed : Type → Type
λ> :synth ((∀ a : Type, (a → QueryClosed.Token) → a →
…>     QueryClosed.Indexed a) → (QueryClosed.Mono → QueryClosed.Token) →
…>     QueryClosed.Mono → QueryClosed.Indexed QueryClosed.Mono)
  it1  fun f => f _
  it2  fun f g x => f _ (fun _ => g x) x
~~~

Both Djinn terms instantiate <code>f</code> at the exact closed query type
<code>QueryClosed.Mono</code>; the second merely chooses a different valid
callback. Standalone Exference returns the compact
<code>fun f =&gt; f _</code>, and combined mode retains both Djinn
spellings. The
[<code>synth-query-closed-rankn</code>](test/synth-query-closed-rankn.txt)
transcript turns live-library premises off and checks all three modes through
final Lean 4.31 elaboration with Exference bounded to 128 steps. The pure
boundary test does the same below the REPL layer.

The new Djinn family is appended after every established structural, provider,
and loaded-scheme family, so historical candidate prefixes do not move. Its
plan carries the established local, loaded, and caller-supplied provider
premises, allowing those capabilities to compose in one proof. It retains the
same six-binder eligibility, 16 axioms per scheme, 64 axioms per family, and
512 tuple attempts. It is positive-only: exhausting this incomplete tail is
<code>NoEvidence</code>, never a proof of uninhabitability.

Context-free hypothesis chains now reach six leading binders. Leant inserts
all six inferred type arguments, and Lean 4.31 verifies a non-lexical
source-order application of an abstract six-argument constructor:

```text
λ> axiom SixBinder.Six : Type → Type → Type → Type → Type → Type → Type
λ> :synth (∀ A B C D E F : Type, (∀ a b c d e f : Type, SixBinder.Six a b c d e f) → SixBinder.Six F E D C B A)
  it1  fun _ _ _ _ _ _ x => x _ _ _ _ _ _
```

Explicit `∀` binders — leading, nested, trailing, or interleaved — are
woven into the candidate's lambda automatically, and uses of quantified
hypotheses get placeholder type arguments wherever Lean needs them
(`f _ x`), so bounded rank-N candidates verify. Chains with seven or more
leading binders remain outside Djinn's fixed instantiation bound. Full
impredicative inhabitation is undecidable, so Djinn uses a deterministic
bounded plan family rather than a power set. Its singleton, pairwise, triple,
quadruple, and quintuple open/opaque frontiers cover every choice across eleven
independent quantified sites. Quintuple selections are edge-balanced and
capped at 512 plans per orientation; this retains all 252 ten-site and 462
eleven-site choices while bounding larger queries. A twelve-site goal needing
exactly six open and six opaque sites is the next deliberate occurrence-plan
gap. Beyond either that occurrence bound or the separate six-binder
instantiation guard, the answer is "no term found within bounds" and nothing
stronger.

The plan-family bounds (which quantifier-site selections are
exhaustive, where the next gap lies) and the dedicated rank-N transcripts
that pin them are catalogued in
[docs/synth-internals.md](docs/synth-internals.md#rank-n-plan-families-and-bounds).

Instance-implicit goal binders keep a separate render-only position. The
engines remain dictionary-independent, while Leant inserts the wildcard that
prevents the next synthesized lambda binder from being mistaken for the class
instance. Uses of a constrained rank-N hypothesis leave its nested instance
argument implicit, so Lean reconstructs the evidence during verification:

```text
λ> :synth (∀ (A R : Type) [Demo.C A], (∀ (a : Type) [Demo.C a], a → R) → A → R)
  it1  fun _ _ _ f => f _
```

Because erased dictionary evidence can carry proof power, its presence also
makes an otherwise empty Djinn search inconclusive rather than a refutation.
The live regression runs this goal under Djinn, Exference, and `both` in
[`synth-instance-implicit`](test/synth-instance-implicit.txt).

### Impossibility, proved

When Djinn's complete search exhausts a fully translated goal, failure
is a theorem — an answer no failing tactic gives you:

```text
λ> :synth (∀ a b : Type, Option a → b)
provably uninhabited — no closed term of this polymorphic type exists
```

The wording is careful: the verdict is about *closed terms of the
polymorphic type* (instantiate `b := Option a` and `id` inhabits it),
and in `Prop` it is about *constructive* provability. When the
translation had to hide structure behind an opaque atom, the verdict
backs off to "no term found within bounds". The proof is complete for the
provider-free structural calculus, but it is only a fallback with respect to
the live Lean environment. Leant still runs its bounded constructive provider
lanes, and the first candidate retained by behavioral assessment wins. If
provider discovery is empty or unavailable, times out, errors, yields no
verified candidate, or has every verified candidate independently rejected,
Leant restores the original proof-backed control-flow fallback. Completed
behavioral outcomes remain accumulated. Provider discovery is
intentionally bounded and best-effort, so that verdict is not an exhaustive
claim about every axiom or declaration in the environment.

The focused
[`synth-provider-refutation-fallback`](test/synth-provider-refutation-fallback.txt)
transcript makes that ordering observable. Exact live rank-N providers override
the provider-free refutation under Djinn, Exference, and `both`; an exact
constructive proof of a Peirce-shaped goal wins while classical fallback is
enabled; and a no-provider control preserves the original sound verdict. Pure
engine tests separately pin a direct provider override, an empty-family
rank-N assignment, and retention of refutation for an unusable provider.

### Classical candidates

After those constructive provider lanes fail, refuted `Prop` goals get a
classical attempt
(disable with `:set synth-classical off`): first with an
excluded-middle case split per atomic subformula, then—after either no
verification or complete behavioral all-rejection—via the Glivenko double-
negation translation wrapped in `Classical.byContradiction`. Excluded middle
remains one six-group batch. A filter-mode double-negation run may consume its
ordinary 12+12 or 24+24 frontier, while rank and disabled modes consume one
12- or 24-group batch. Both attempts use the same command-local assessment
context and are finalized together. Filtering also keeps the command's
original absolute deadline through both routes; rank and disabled commands
allocate a fresh configured-duration deadline separately at each route they
actually reach.
Peirce's law has no constructive inhabitant — `:synth` proves that,
then answers the classical question with a term whose spelling shows
exactly what was used:

```text
λ> :synth (∀ p q : Prop, ((p → q) → p) → p)
  it1  fun _ _ f => match Classical.em _ with | .inl x => x | .inr k => f (fun y => absurd y k)
  ⋯
λ> :set synth-classical off
synth classical: off
λ> :synth (∀ p : Prop, p ∨ ¬ p)
provably uninhabited — no closed term of this polymorphic type exists
(constructively — a classical proof may still exist; this is not a disproof of the proposition)
```

The hard direction of De Morgan needs excluded middle twice, once per
disjunct, and the candidate reads as exactly that case analysis:

```text
λ> :set synth-classical on
synth classical: on
λ> :synth (∀ p q : Prop, ¬(¬p ∧ ¬q) → p ∨ q)
  it1  fun _ _ k => match Classical.em _ with | .inl x => .inl x | .inr k1 => (match Classical.em _ with | .inl y => .inr y | .inr k2 => absurd ⟨k1, k2⟩ k)
```

### Inductive types

A non-recursive, non-indexed inductive or structure — built-in
(`Bool`, `Option`, `Ordering`, `Except`, `Decidable`, …) or
session-declared — expands into a generalized sum of products:
constructors become introduction rules, case analysis the elimination
rule, and candidates render with the real constructor names. When all applied
parameters are proper types, Leant also retains the exact family head and
ordered parameter vector. A query-wide pre-scan validates one shared
parameterized declaration, so rank-N transport no longer requires choosing
between nominal identity and useful constructor structure.
`Except.map`, synthesized rather than remembered:

```text
λ> :synth (∀ e a b : Type, Except e a → (a → b) → Except e b)
  it1  fun _ _ _ x f => match x with | .error y => .error y | .ok z => .ok (f z)
```

It extends to `Type`-valued classes-as-data like `Decidable`, where the
instance combinators write themselves — decidability of implication,
by case analysis on both instance arguments:

```text
λ> :synth (∀ p q : Prop, Decidable p → Decidable q → Decidable (p → q))
  it1  fun _ _ x y => match x with | .isFalse k => .isTrue (fun z => absurd z k) | .isTrue w => (match y with | .isFalse k1 => .isFalse (fun f => k1 (f w)) | .isTrue x1 => .isTrue (fun _ => x1))
note: search truncated: candidate limit reached (60)
```

Session-declared types participate the moment you declare them, and
refutations over expanded inductives stay sound — the engine saw the
complete constructor list:

```text
λ> structure Pair (A B : Type) where
…>   fst : A
…>   snd : B
…>
λ> :synth (∀ a b : Type, a → b → Pair a b)
  it1  fun _ _ x y => ⟨x, y⟩
λ> :synth (∀ a b : Type, Pair a b → Empty)
provably uninhabited — no closed term of this polymorphic type exists
```

Fixed constructor fields are not mistaken for family parameters. Here
`Demo.Secret` becomes one private rigid proper type inside the engine, while
the varying `a` remains the parameter of `Demo.Guard`; both engines can still
transport the whole family at an impredicative argument:

```text
λ> axiom Demo.Secret : Type
λ> inductive Demo.Guard (a : Type 1) : Type 1 where
…> | mk : Demo.Secret → a → Demo.Guard a
…>
λ> :synth ((∀ a : Type 1, Demo.Guard a) → Demo.Guard (∀ b : Type, b → b))
  it1  fun x => x _
```

Sharing is conservative and independent of traversal order. Every occurrence
of an exact head in the goal, caller premises, and usable live providers
must agree on arity and on one generic constructor schema. Repeated or
otherwise ambiguous parameter vectors may borrow a template from a later,
unambiguous occurrence only when specialization reproduces every inventory.
If no unique compatible template exists—or the same head also arrived through
an opaque nominal fallback—the whole head becomes one shared abstract family.
Transport can still succeed, but constructors and cases are withheld, and
Djinn cannot turn search exhaustion into a refutation. Unsafe atoms in caller
premises likewise forfeit negative evidence. Exference never makes negative
claims, and every positive candidate from either engine is still checked by
Lean. A contradictory arity for one exact Lean head is rejected outright
rather than abstracted or conflated.

Recursive proper-type applications now receive the same query-wide exact-head
identity discipline, with a recursive-specific schema check. This lets both
engines transport a quantified family value directly to a supplied
impredicative parameter—for example, the verified answers to a base-less
`RecBox` query include `fun x => x _`; standalone Exference now also verifies
the constructor-shaped `fun x => ⟨fun _ y => y, x _⟩`. Recursive self fields
are normalized to the generic applied family before schemas are compared, so
`List a` and `List b` can validate one recursive knot even though Lean
serialized different display keys.

The available structure remains intentionally asymmetric. When every reachable
occurrence has a complete, compatible schema and a pairwise-distinct parameter
vector yields a closed template that fits every observed occurrence, both
engines receive one shared native recursive declaration. A plain-variable
vector is direct generic evidence; a structured vector is only a speculative
positive approximation because the serialized fields lack declaration-level
parameter provenance. Every resulting term is re-elaborated by Lean, and the
approximation supplies no negative evidence. Djinn may introduce one
constructor layer from each of at most two independent recursive SCCs on a
positive logical path, but it cannot eliminate recursive inputs; Exference may
inspect one constructor layer, whose recursive fields become ordinary
branch-local values and are not immediately split again. It first preserves
the established all-inputs-used candidate prefix and tries the omission lane
only after a miss. Partial inventories, unresolved repeated parameters,
structured templates that fail the closure/fitting checks, incompatible
schemas, and nominal collisions all choose one shared abstract exact family;
their occurrence constructors remain introduction premises, but no `match` is
exposed, and Djinn search exhaustion is not promoted to a refutation. Indexed
(`Eq`) and dependent-field (`Exists`)
types remain opaque. The main impredicative gain is direct family transport,
not recursion or induction.

### Recursion from the library

`:synth` will never invent a `Nat.rec`-based program, but it does not
have to: for the everyday recursive types, the library already wrote
the recursion. A goal that mentions `List` or `Nat` brings a rated
inventory of library functions with it (`List.map`, `List.foldr`,
`List.append`, `List.flatten`, `List.length`, `List.replicate`,
`Nat.add`, …), instantiated at the goal's own types and handed to the
engine as extra premises — the phase-3 promise of *recursion via
library reuse*, in miniature. The enumeration prefers proofs that use
the goal's own arguments, generally putting the direct library answer
first while retaining distinct choices between same-typed arguments:

```text
λ> :synth ((a → b) → List a → List b)
  it1  fun f x => List.map f x
  it2  fun f x => List.reverse (List.map f x)
  ⋯
λ> :synth (List (List a) → List a)
  it1  fun x => List.flatten x
  it2  fun x => List.reverse (List.flatten x)
  ⋯
λ> :synth (List a → Nat)
  it1  fun x => List.length x
  it2  fun x => Nat.add (List.length x) (List.length x)
  ⋯
λ> :synth (Nat → a → List a)
  it1  fun x y => List.replicate x y
  ⋯
λ> :synth (List a → List b → List (a × b))
  it1  fun x y => List.zip x y
  ⋯
λ> :synth ((a → b → c) → List a → List b → List c)
  it1  fun f x y => List.zipWith f x y
  ⋯
λ> :synth (List a → List a → List a)
  it1  fun x _ => x
  it2  fun _ x => x
  it3  fun x _ => List.reverse x
  it4  fun x y => List.append x y
  it5  fun x y => List.append y x
```

The inventory is a ratings list in Djex's `*.ratings` format — lower
is better, 100 or more disables — and a project file `leant.ratings`
(lines of `Name Rating`, `#` comments) merges over the defaults at
startup, so re-ranking, disabling, or growing the inventory is
editing a list, not writing code.

The library search runs beside the plain constructor search, and its
candidates come first — they are found in a mode where the recursive
occurrences are sealed atoms, so every candidate must route through
the goal's own arguments and the offered functions rather than
through constructor junk (`List.nil` inhabits every `List` goal; a
search that may use it drowns in closed terms that ignore the
input). Both searches' candidates are verified and shown together,
and `:set synth-library off` restores the constructors-only
behavior. Negative verdicts are unaffected: goals that mention a
recursive inductive already report "no term found within bounds"
rather than a refutation, and the library run never contributes a
negative verdict at all.

### Dependent formulas as cargo

Dependent subformulas (`∀ n : Nat, P n`) are carried as opaque atoms,
compared up to α-equivalence: transportable, never analyzed.

```text
λ> opaque P : Nat → Prop
λ> opaque Q : Prop
λ> :synth ((∀ n : Nat, P n) ∧ Q → Q ∧ (∀ n : Nat, P n))
  it1  fun ⟨x, y⟩ => ⟨y, x⟩
```

The engine never looked inside `∀ n, P n`; it swapped a sealed box. A
goal that would require opening the box — an induction, a rewrite, a
case split on an index — is refused with a reason; that work belongs to
`:prove`.

### Synthesis inside a proof

Bare `:synth` in prove mode targets the current goal *with its
hypotheses as premises*, and `itN` splices the candidate applied to
those hypotheses, so `exact it1` closes the goal:

```text
λ> :prove ∀ p q : Prop, (p → q) → p → q ∧ p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p q : Prop), (p → q) → p → q ∧ p
suggestion: exact fun p q a a_1 => ⟨a a_1, a_1⟩  (closes the goal)
⊢> intro p q h hp
p q : Prop
h : p → q
hp : p
⊢ q ∧ p
suggestion: exact ⟨h hp, hp⟩  (closes the goal)
⊢> :synth
(synthesizing with hypotheses p q h hp as premises)
  it1  fun _ _ f x => ⟨f x, x⟩
⊢> exact it1
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed mp_and
saved: theorem mp_and : ∀ p q : Prop, (p → q) → p → q ∧ p
```

Unlike `exact?`, which finds an *existing* lemma, this composes a new
term from the goal's own material — a constructive complement to the
finisher tactics, needing no premise database and no imports. Bare
`:synth` outside prove mode targets the last `sorry`.

The classical fallback follows you into prove mode: double-negation
elimination has no constructive proof, so `:synth` offers the
excluded-middle case split, and `:qed` turns it into a theorem —
proved, verified, and named without writing a single tactic beyond
`exact`:

```text
λ> :prove ∀ p : Prop, ¬¬p → p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p : Prop), ¬¬p → p
suggestion: exact fun p a => Classical.byContradiction a  (closes the goal)
⊢> :synth
  it1  fun _ k => match Classical.em _ with | .inl x => x | .inr k1 => absurd k1 k
⊢> exact it1
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed not_not_elim
saved: theorem not_not_elim : ∀ p : Prop, ¬¬p → p
```

### Engines, budgets, and the fine print

- Library premises are on by default (`:set synth-library on|off`);
  the rated inventory (defaults merged with `leant.ratings`) only ever
  *offers* premises — the driver filters them against the goal's own
  types and the backend verifies every candidate, so a useless entry
  costs search time, never soundness. The ratings file is read at
  startup; edits take effect next session.
- A second engine is available: `:set synth-engine exference` switches
  to Djex's ranked heuristic search (explicit budgets, no negative
  verdicts; `:set synth-steps N` bounds it, default 4096), and `both`
  runs the two together. Standalone lanes send at most 12 fresh candidate
  groups to Lean (`:set synth-verify N`); a combined lane gets twice that
  and preserves both standalone frontiers. Writing `D` and `E` for fresh
  Djinn and Exference groups, its order is `D1–D4, E1–E12, D5–D12`, followed
  by alternating tails: the Djinn head is one short of `synth-shown` and each
  front runs to `synth-verify`, so retuning either setting reshapes the
  interleave accordingly.
  Within each Exference invocation, Leant stable-deduplicates rendered groups
  before applying the internal 60-candidate collection window
  (`:set synth-window N`). The first
  spelling remains authoritative, while repeated backend derivations cannot
  consume slots ahead of later distinct terms. Ranking and disabled commands
  retain one outer batch of `synth-verify` groups (default 12, or 24 for
  `both`) and ranking stops after `synth-shown` accepted groups (default
  five). Filtering may consume one successor of the same width after a first
  no-verification or all-rejected batch, for a 12+12 standalone or 24+24
  combined maximum at the defaults from the same engine outcome, before its
  `synth-shown` presentation cap. There is no third probe. Combined exact-text deduplication
  likewise keeps the first display occurrence. If that occurrence has no typed
  authority, the exact spelling may lazily retain the first bounded later
  Exference origin solely for checked behavioral preparation; route metrics,
  ordinals, sibling variants, and displayed order do not change.
  Refutations still come only from Djinn. The default `djinn` remains the
  complete, terminating LJT search.
- Every engine mode gives a structurally accepted goal a provider-free
  baseline lane. Its rendered candidates are checked by Lean first, and live
  providers are discovered whenever no baseline term verifies or an authorized
  filter rejects every verified baseline occurrence (`:set synth-providers
  off` skips discovery; `:set synth-provider-cap N` bounds how many providers
  one discovery serializes, default 80). The same command-local
  filter bank and accumulated rejection history cross those runs. A complete
  Djinn refutation is retained provisionally while the constructive provider
  lanes run: the first batch with any surviving or preserve-all result wins,
  while empty, all-rejected, unavailable, timed-out, or unsuccessful provider
  search restores the proof-backed control-flow fallback. Completed provider
  outcomes are not discarded. Only then does the explicit classical fallback
  run.
  Provider-eligible atomic/refused goals go directly to provider search.
  Djinn first isolates the highest-ranked provider, then widens through the
  first 4 and 16 providers before the full bounded inventory after verified
  misses; Exference keeps its internally rated full-inventory lane. Combined
  mode runs both engines for the singleton and full lanes but uses Djinn alone
  for the intermediate prefixes. Baseline and provider lanes consume one
  command-wide deadline (`:set synth-timeout`), including both batches of a
  filter run. Before a later provider lane is forced or capped, every spelling
  in an earlier completed no-verified or all-rejected run frontier is removed
  from each source stream and newly empty groups are dropped.
  Rediscovered candidates therefore consume no fresh lane quota. Continuation
  does not collect five survivors across lanes: one survivor is terminal. This
  policy
  deliberately favors a structural solution over breadth: provider
  alternatives are not enumerated after a baseline term succeeds. See the
  dated
  [provider-isolation report](docs/reports/2026-08-01-provider-isolated-exference-baseline.md).
- When an engine needs live values, Leant takes a bounded inventory from the
  live Lean environment. It considers constants under namespaces named
  by the target, plus exact declarations from the current session;
  rejects generated names; prioritizes exact-result session and public
  declarations before unrelated session values; and serializes at most
  80 term providers (`:set synth-provider-cap N`). Declarations whose fully peeled result is a sort
  (type constructors and type families) are excluded before search.
  Conventional implementation workers ending in `TR`,
  `Impl`, or `Aux` (or a `.go`/`.loop` component) remain eligible but
  move behind public fallbacks; exact user-session declarations always
  bypass that spelling heuristic. Exference assigns increasing positive
  penalties in this order, while Djinn receives the sparse-prefix schedule
  above. Thus a
  target such as `(α → β) → List α → List β` can reuse
  `List.map` instead of rebuilding recursion from scratch.
- The goal serializer also supplies a canonical provider query: the
  target's sorted, deduplicated root namespaces and its final result
  head. Leant keys a generation-aware, 12-entry LRU by that semantic
  query rather than by raw goal text. Successful empty inventories are
  cached too; discovery failures are not. Any operation that can change
  imported or session declarations advances the generation and clears
  the cache, while generated `it1`, `it2`, … bindings are excluded from
  provider discovery and deliberately preserve it.
- Providers receive collision-free private names inside Djex. Rendering
  maps those names back to the exact fully-qualified Lean globals before the
  backend verifies the candidate. Live discovery also retains the source names
  of leading type binders. When Djex makes a vacuous specialization
  visible, Leant renders a named argument such as
  `Demo.global («a» := Nat)`; intervening instance binders stay implicit and
  Lean reconstructs their dictionaries. Historical caller-owned inventories
  without binder metadata retain the positional `@` fallback. Inventory
  extraction is deliberately best-effort: if it cannot be produced, each
  engine still runs with the structural declarations it already has.
- Exact polymorphic providers whose class constraints pin down their type
  arguments can be discovered together with the instance-head evidence that
  determines those arguments, within fixed bounds (six binders, 32 heads, 16
  vectors per provider); the exact vectors, kinds, wire format, and ground-fact
  rules are specified in
  [docs/synth-internals.md](docs/synth-internals.md#provider-instantiation-evidence).
- Non-dependent instance-implicit binders in a goal are serialized as
  render-only slots. They are erased before either engine searches, reserve a
  wildcard in an introduced Lean lambda, stay implicit at hypothesis and
  provider applications, and poison complete negative evidence. This keeps
  dictionary reconstruction with Lean without shifting later synthesized
  term arguments.
- Applications of type constructors — bound variables, opaque Lean
  constants, and qualifying inductive families such as `Option`, `Except`,
  and user declarations — keep their arguments and, for families, share one
  parameterized declaration across the whole goal; the plan rules and the
  refutation-safety consequences are specified in
  [docs/synth-internals.md](docs/synth-internals.md#proper-type-applications-and-family-plans).
- Where a term's shape is ambiguous in Lean (a quantified hypothesis
  may be transported whole or instantiated), the renderer offers the
  alternatives and verification picks the one that elaborates.
- Auto-bound goal variables default to `Sort`; when Type-level `×`/`⊕`
  over arrows leaves Lean's universe unifier stuck, `:synth` retries
  with the unresolved variables bound at `Type` (noted in the output).
  Names that resolve in the session — including through an opened
  namespace — are never shadowed.
- The pure searches answer in microseconds; the cost center is backend
  verification, a few hundred milliseconds per candidate. A wall-clock
  guard (default 20 s; `:set synth-timeout N` changes it for the session,
  `LEANT_SYNTH_TIMEOUT=N` seeds it at startup, `0` waits indefinitely)
  covers quantified goals whose bounded instantiation widens the
  space. The same deadline covers the baseline and every provider fallback
  rather than restarting for each lane; filter mode carries that original
  absolute deadline through excluded middle and double negation as well. Rank
  and disabled modes preserve their historical classical budgets by capturing
  an independent fresh configured duration at each classical route actually
  reached. Hitting any such boundary is reported as "no answer", never as a
  verdict.
- `:set synth-debug on` (or `LEANT_SYNTH_DEBUG=1` at startup) prints the
  translated fragment, discovered providers, rendered variants, and stable
  `code=count` verification metrics — the fastest way to see why a candidate
  was dropped and how much Lean work the lane performed.

### Session settings

Every knob above is a `:set` setting; given without a value it prints its
current state, and a bare `:set` prints them all. Defaults reproduce the
historical constants, so a fresh session behaves exactly as documented.

| Setting | Default | Meaning |
|---|---|---|
| `synth-engine djinn\|exference\|both` | `djinn` | which Djex search runs |
| `synth-steps N` | 4096 | Exference step budget |
| `synth-queue N` | 1024 | Exference queue bound |
| `synth-budget N\|off` | `off` | Djinn choice-point budget of the ordinary and provider lanes |
| `synth-window N` | 60 | candidate groups one lane may observe |
| `synth-verify N` | 12 | fresh candidate groups Lean checks per lane (`both` sends twice that, and the batch is clamped to `synth-window`) |
| `synth-shown N` | 5 | accepted groups shown, and the ranking stop |
| `synth-classical on\|off` | `on` | excluded-middle and double-negation fallbacks |
| `synth-library on\|off` | `on` | rated library premises for recursive inductives |
| `synth-library-premises N` | 8 | rated offers kept per goal (`:set synth-ratings` lists the inventory) |
| `synth-providers on\|off` | `on` | discover live providers after the structural lane |
| `synth-provider-cap N` | 80 | providers one discovery may serialize |
| `synth-timeout N` | 20 (`LEANT_SYNTH_TIMEOUT`) | wall-clock seconds per `:synth`; `0` waits indefinitely |
| `backend-timeout N` | 300 (`--timeout`) | seconds per Lean request; `0` none |
| `synth-debug on\|off` | `off` (`LEANT_SYNTH_DEBUG`) | fragment, provider, lane, and metric diagnostics |

## How it works

The design below — a Haskell REPL and synthesis engine driving a Lean
worker over a text protocol — is examined at length in the
[Lean 4 rewrite analysis](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Leant_Djex_Lean4_Rewrite_Analysis/Leant_Djex_Lean4_Rewrite_Analysis.pdf),
which asks which of these boundaries would survive reimplementing both
projects in Lean itself.

Leant implements the backend protocol directly
([src/Leant/Backend.hs](src/Leant/Backend.hs)): JSON over stdin/stdout
with blank-line framing, spawned as `lake env repl` (`repl.exe` on
Windows) inside the Lake project. The JSON codec is hand-rolled
([src/Leant/Json.hs](src/Leant/Json.hs)), so the REPL core itself needs
only GHC boot libraries; the sole Hackage dependency, `haskell-src-exts`,
arrives through the vendored Djex. On backend death,
timeout, or Ctrl+C, the process is killed and the session (imports +
history) replays automatically on the next command. The Haskeline
front-end provides the interrupt-safe step loop, logical multi-line
input, and completion.

An unpickled environment becomes an explicit history and undo barrier.
Leant keeps a private process-lifetime copy, so backend restart does not
depend on the user leaving the source file in place; commands entered after
the barrier replay normally and remain undoable. `:reset` or `:load` leaves
snapshot mode and rebuilds configured imports, while `:import` asks for one
of those explicit transitions because Lean cannot add imports to an existing
opaque environment.

`:pickle` publishes the ordinary `.olean` first-class artifact together with
a versioned `.leant.json` sidecar and, when synthesis tooling can be prepared,
a `.leant-synth.olean` sibling. Content fingerprints and the serializer ABI
prevent stale siblings from being trusted. Missing, stale, or foreign metadata
does not block `:unpickle`; such a snapshot is restored as an upstream snapshot
and Leant builds synthesis tooling over it when its imports expose Lean's
metaprogramming API.

A `:synth` query passes through checked stages. A Lean metaprogram
(compiled once into a cached side environment) elaborates the goal and
serializes it into the engine's fragment; the fragment translator accepts
it or refuses with a reason. The engine first searches without providers
and the backend re-elaborates its rendered candidates against the original
goal; only if no provider-free term verifies, or an authorized filter rejects
all verified baseline occurrences, does a second metaprogram build the bounded
live-provider inventory and run the fallback lanes described
under [Engines, budgets, and the fine print](#engines-budgets-and-the-fine-print).
A complete Djinn refutation is kept as a sound fallback while those
constructive lanes run and restored if they find no survivor. Constructor and
exact provider names are restored and binders named by role before every
verification; only survivors are bound, while accumulated behavioral
rejections remain separately visible.

For startup and contract-file commands, Main opens the one rank-2 Length
context before goal translation, preserving the established lifetime through
universe retry and every synthesis lane. For the inline form, Main first owns
the fixed-order command parse, goal selection, literal-filter authorization,
bounded clause parse, the established inaccessible-hypothesis and premise-scope
report, Lean translation/retry, and `SlotArrow`-only physical arity resolution.
It opens exactly one scalar or product context only after resolution succeeds,
then passes the same context through every ordinary, provider, excluded-middle,
and double-negation lane. Quantifiers, instance binders, and contextual slots
do not count as physical `argN` positions.

The synthesis side environment tracks exactly which session history it
has replayed. An unchanged history reuses it directly; an append replays
only the new suffix; undo or another non-prefix change rebuilds from the
cached import-and-serializer base. For a restored Leant snapshot that base is
the saved synthesis companion, so snapshot-only declarations remain visible
to goal translation and live-provider discovery. Generated result bindings still join
that replay history so later goals can mention them, but because they
cannot be providers they do not invalidate a reusable provider
inventory.

## Development

The focused Haskell suite covers fragment/provider parsing, engine
isolation, exact global rendering, and synthesis behavior:

```bash
cabal test leant-synth-tests --test-show-details=direct
```

Golden transcript tests live in [test/](test/): `bash test/run-tests.sh`
passes each `*.txt` through `leant --plain` and diffs the filtered
output against the checked-in `*.golden`; `-u` regenerates the goldens
after an intentional behavior change. The runner raises the `:synth` wall
clock to 600 s so a transcript records what the engines answer rather than
how fast the machine answers it; export `LEANT_SYNTH_TIMEOUT` to override.
These end-to-end goldens require
the Lake project to provide the backend executable (`repl` or
`repl.exe`); the focused suite remains runnable when that backend is not
installed. On a machine without the LeanInteract cache the discovery
scans (for example Linux), point `LEANT_BACKEND` at a built
`repl` binary -- clone `augustepoiroux/repl` at the tag matching the
cached Windows revision (currently
`v1.3.18_lean-toolchain-v4.32.0`), run `lake build`, and export the
path to `.lake/build/bin/repl`; the very first heavy `:synth` there may
pay one cold-toolchain warm-up against the 300 s per-request backend
timeout and succeed on retry.

Two things make a fresh run easier to read. First, the suite passes in
full on every platform (the two historical Windows path-admission
failures now spell their absolute fixture paths per platform), with one
caveat: `compose a persistent last-wins builder and admit before clock
capture` races a fake solver's start-up against a 700 ms budget and can
fail on a slow or loaded machine while passing in isolation. Treat any
*other* failure as a regression. Second, seventeen tests
read production source text and assert on it — thirteen on
[src/Main.hs](src/Main.hs), and one or two each on `Synth/Engine.hs`,
`Synth/BehavioralSelection.hs` (and its `Internal`), the scalar and
`SpinePair` `Length/Ranking` and `Length/Selection` modules together with
`Ranking/Generic.hs` and `Selection/Generic.hs`,
`Length/CounterexampleBank/Internal.hs`, `Length/Integration.hs`,
`Length/Handoff.hs`, and — for the active inline `--where` runtime —
`Length/Command.hs` and `Length/Where.hs` (all under `src/Leant/` unless
shown otherwise).
They pin the shape of decisions that must not move
silently, such as which deadline a classical route owns and that selection
preserves the batch before it seals. A refactor of those files has to be
re-run against the focused suite even when it is provably behaviour
preserving; when a lint or a cleanup fights one of those pins, the pin wins.

Ideas under consideration are tracked in
[docs/PROPOSALS.md](docs/PROPOSALS.md) and
[docs/SYNTHESIS_PROPOSAL.md](docs/SYNTHESIS_PROPOSAL.md).

## License

Available under [MIT-0](LICENSE).
