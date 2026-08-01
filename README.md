# Leant — a Djex-based synthesis REPL for Lean 4

Leant brings [Djex](lib/Djex)-powered program and proof synthesis to
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

There is a manual: **[docs/Leant.pdf](https://raw.githubusercontent.com/VladimirReshetnikov/Leant/main/docs/Leant.pdf)**
— an overview and tutorial, with a detailed tour of `:synth`
([LaTeX source](docs/Leant.tex)).

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
leant [FILE] [--project DIR] [--plain] [-i MOD]
      [--timeout N] [--time] [--transcript [FILE]] [--timestamps]
      [--repl-exe PATH] [--lake PATH]
```

Run inside a Lake project (auto-detected, or `--project DIR`) to make
the project's modules and dependencies importable, or `--plain` for a
bare stdlib session with subsecond startup. Expressions evaluate via
`#eval` with `#check` fallback; declarations (`def`, `theorem`,
`inductive`, `open`, …) run verbatim and, on success, advance the
session environment; `#`-commands pass straight through.

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
a tactic; goals reprint after each one; `:undo` takes back steps without
limit; `:script` shows the accumulated proof; `:auto` tries common
finishers; `:qed [NAME]` turns the script into a real theorem in the
session. `?`-tactics (`exact?`, `simp?`, `rw?`) record the tactic they
*found* rather than the question-mark form. Proof-state identifiers belong
to one backend process: if that process stops, Leant leaves prove mode and
prints the accumulated script instead of submitting a stale identifier after
the session restarts.

```text
λ> :prove ∀ p q : Prop, p ∧ q → q ∧ p
entering prove mode — type tactics; :help for commands
⊢ ∀ (p q : Prop), p ∧ q → q ∧ p
⊢> intro p q h
p q : Prop
h : p ∧ q
⊢ q ∧ p
⊢> exact ⟨h.2, h.1⟩
All goals accomplished 🎉
finish with :qed [NAME], inspect with :script
⊢> :qed and_swap
saved: theorem and_swap : ∀ p q : Prop, p ∧ q → q ∧ p
```

## `:synth` — automatic term synthesis

`:synth TYPE` answers the question *"write me a term of this type"* —
read through propositions-as-types, *"prove this"* — and sometimes the
stronger question *"show me that no such term exists."* It covers the
structural fragment `→ / × / ∧ / ⊕ / ∨ / ↔ / ¬ / ⊥ / ⊤ / ∀` over opaque
variables, plus structurally representable inductive data, with bounded
support for rank-N and impredicative quantification. Exference can
additionally reuse a small, goal-relevant slice of the live Lean
environment. Design and phasing:
[docs/SYNTHESIS_PROPOSAL.md](docs/SYNTHESIS_PROPOSAL.md).

The engine is the vendored [Djex](lib/Djex) library, linked in-process.
Djex began as a merger of two classic Haskell synthesizers — **Djinn**
(complete, terminating proof search for intuitionistic propositional
logic, Dyckhoff's LJT calculus) and **Exference** (ranked heuristic
search under explicit budgets) — but has grown well beyond either
original: a shared, validated synthesis foundation with checked
boundaries; a unified type-class constraint contract spanning both
engines; fixes for long-standing soundness bugs (an exhausted search
over an *approximated* goal no longer counts as a refutation); and,
most importantly here, a principled treatment of **rank-N and
impredicative types** — goal-side quantifiers open through
polarity-aware plan families, quantified hypotheses are instantiated at
a bounded, sequent-supplied set of types, and impredicative
instantiation is admitted under a guard that never invents a polytype
the query did not supply.

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
capital identifiers are auto-bound, so quick queries stay quick.
Candidates are ranked smallest-first and *bound into the session* as
`it1`, `it2`, …, with bare `it` the best one — they are ordinary
definitions, so you can evaluate them immediately:

```text
λ> :synth (a → a → a)
  it1  fun _ x => x
  it2  fun x _ => x
λ> #eval it2 "left" "right"
"left"
λ> :synth (∀ p q : Prop, ¬(p ∨ q) ↔ ¬p ∧ ¬q)
  it1  fun _ _ => ⟨fun k => ⟨fun x => k (.inl x), fun y => k (.inr y)⟩, fun ⟨k1, k2⟩ z => match z with | .inl w => k1 w | .inr x1 => k2 x1⟩
```

Both inhabitants of `a → a → a` that matter, and one direction each of
De Morgan's law, packed into an `Iff` by the anonymous constructor.
Binders are named by role — functions `f g h`, values `x y z`,
negations and continuations `k` — which keeps large candidates
readable.

### Programs you already know

Some types have one sensible inhabitant, and asking for it by type is
quicker than remembering which library corner it lives in. The bind of
the state monad:

```text
λ> :synth ((S → A × S) → (A → S → B × S) → S → B × S)
  it1  fun f g x => match f x with | ⟨a, b⟩ => g a b
  it2  fun f g x => match f x with | ⟨a, _⟩ => g a x
  ⋯
```

The first candidate threads the state correctly. The second is
type-correct and runs `g` on the *initial* state — the classic
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
  it3  fun f x => f _ x
```

And a Church-encoded pair converts into a real conjunction — the
quantified hypothesis is instantiated once at `p` and once at `q`, fed
the matching projection each time:

```text
λ> :synth (∀ p q : Prop, (∀ r : Prop, (p → q → r) → r) → p ∧ q)
  it1  fun _ _ f => ⟨f _ (fun x _ => x), f _ (fun _ y => y)⟩
  ⋯
```

Explicit `∀` binders — leading, nested, trailing, or interleaved — are
woven into the candidate's lambda automatically, and uses of quantified
hypotheses get placeholder type arguments wherever Lean needs them
(`f _ x`), so bounded rank-N candidates verify. Full impredicative
inhabitation is undecidable, so Djinn uses a deterministic quadratic
plan family rather than a power set. Its singleton and pairwise
open/opaque frontiers cover every choice across five independent
quantified sites; a six-site goal needing exactly three open and three
opaque sites remains a deliberate bounded gap. Beyond the guard the
answer is "no term found within bounds" and nothing stronger.

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
backs off to "no term found within bounds".

### Classical candidates

Constructively refuted `Prop` goals get a second, classical attempt
(disable with `:set synth-classical off`): first with an
excluded-middle case split per atomic subformula, then via the Glivenko
double-negation translation wrapped in `Classical.byContradiction`.
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

### Inductive types

A non-recursive, non-indexed inductive or structure — built-in
(`Bool`, `Option`, `Ordering`, `Except`, `Decidable`, …) or
session-declared — expands into a generalized sum of products:
constructors become introduction rules, case analysis the elimination
rule, and candidates render with the real constructor names.
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

Djinn keeps recursive types such as `Nat` and `List` opaque, with their
constructors available only as introduction rules. When Lean can serialize
the complete constructor inventory and a safe parameter vector, Exference
may also inspect one constructor layer: it can synthesize a finite `match`, but
recursive fields become ordinary branch-local values and are not
immediately split again. This bounded rule cannot invent recursion or
induction; it can, however, combine the finite case split with a live
library provider for the recursive work. Partial inventories remain
introduction-only, while indexed (`Eq`) and dependent-field (`Exists`)
types remain opaque.

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
⊢> intro p q h hp
p q : Prop
h : p → q
hp : p
⊢ q ∧ p
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

### Engines, budgets, and the fine print

- A second engine is available: `:set synth-engine exference` switches
  to Djex's ranked heuristic search (explicit budgets, no negative
  verdicts; `:set synth-steps N` bounds it, default 4096), and `both`
  runs the two together — Djinn's candidates first, Exference's new
  ones after, refutations only from the engine entitled to them. The
  default `djinn` remains the complete, terminating LJT search.
- Before an Exference search, Leant takes a bounded inventory from the
  live Lean environment. It considers constants under namespaces named
  by the target, plus exact declarations from the current session;
  rejects generated names; prioritizes exact-result session and public
  declarations before unrelated session values; and serializes at most
  80 providers. Conventional implementation workers ending in `TR`,
  `Impl`, or `Aux` (or a `.go`/`.loop` component) remain eligible but
  move behind public fallbacks; exact user-session declarations always
  bypass that spelling heuristic. Increasing positive penalties preserve
  the order during search, so the broader fallback pool does not drown
  the most relevant constants. Thus a
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
  maps those names back to the exact fully-qualified Lean globals (and
  uses Lean's `@` spelling for visible type applications) before the
  backend verifies the candidate. Inventory extraction is deliberately
  best-effort: if it cannot be produced, Exference still runs with the
  structural declarations it already has.
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
  guard (default 20 s, `LEANT_SYNTH_TIMEOUT=N`, `0` waits indefinitely)
  covers quantified goals whose bounded instantiation widens the
  space; hitting it is reported as "no answer", never as a verdict.
- `LEANT_SYNTH_DEBUG=1` prints the translated fragment and the rendered
  variants — the fastest way to see why a candidate was dropped.

## How it works

Leant implements the backend protocol directly
([src/Leant/Backend.hs](src/Leant/Backend.hs)): JSON over stdin/stdout
with blank-line framing, spawned as `lake env repl.exe` inside the Lake
project. The JSON codec is hand-rolled
([src/Leant/Json.hs](src/Leant/Json.hs)), so the REPL core builds with
GHC boot libraries only — no Hackage downloads. On backend death,
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

A `:synth` query passes through checked stages: a Lean metaprogram
(compiled once into a cached side environment) elaborates the goal and
serializes it into the engine's fragment; the fragment translator
accepts it or refuses with a reason; for Exference, a second
metaprogram builds the bounded live-provider inventory; the selected
engine searches; candidates are rendered back into Lean syntax with
constructor and exact provider names restored and binders named by
role; and the backend re-elaborates each candidate against the original
goal — only survivors are shown and bound.

The synthesis side environment tracks exactly which session history it
has replayed. An unchanged history reuses it directly; an append replays
only the new suffix; undo or another non-prefix change rebuilds from the
cached import-and-serializer base. For a restored Leant snapshot that base is
the saved synthesis companion, so snapshot-only declarations remain visible
to goal translation and live-provider discovery. Generated result bindings still join
that replay history so later goals can mention them, but because they
cannot be providers they do not invalidate a reusable provider
inventory.

## The Python edition

[LeantPy/](LeantPy/README.md) contains the Python edition of Leant: a
single-file GHCi-style shell over
[LeanInteract](https://github.com/augustepoiroux/LeanInteract) with the
same command set and session semantics. The Haskell implementation is
the primary one, where new development happens; we keep the Python
edition up to date with it (minus `:synth`, which needs the in-process
synthesis engine).

## Development

The focused Haskell suite covers fragment/provider parsing, engine
isolation, exact global rendering, and synthesis behavior:

```bash
cabal test leant-synth-tests --test-show-details=direct
```

Golden transcript tests live in [test/](test/): `bash test/run-tests.sh`
pipes each `synth-*.txt` through `leant --plain` and diffs the filtered
output against the checked-in `*.golden`; `-u` regenerates the goldens
after an intentional behavior change. These end-to-end goldens require
the Lake project to provide the backend executable (`repl` or
`repl.exe`); the focused suite remains runnable when that backend is not
installed. Ideas under consideration are tracked in
[docs/PROPOSALS.md](docs/PROPOSALS.md) and
[docs/SYNTHESIS_PROPOSAL.md](docs/SYNTHESIS_PROPOSAL.md).

## License

Dedicated to the public domain where that is legally effective, and
otherwise available under MIT-0 — both texts are in
[LICENSE](LICENSE).
