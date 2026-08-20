# Host-native behavioral constraints in both REPLs

Date: 2026-08-20

## Outcome

Behavioral Length constraints are now first-class command surfaces in both
standalone REPLs. The common case is one line and uses notation recognizable
to users of the host language:

```text
-- Leant
:synth --where List.length result = List.length arg0 -- List Nat -> List Nat

-- Djex
:exference --where length result == length arg0 -- [a] -> [a]
```

Neither command executes the clause as Lean or Haskell code. Each nominally
separate parser lowers its bounded host-shaped spelling to Djex's existing
opaque Length contract source. The checked contract, SMT-LIB query, live Z3
runner, and exact candidate-specific replay remain the semantic boundary.

## Why the surface changed

The first Leant inline entrance deliberately exposed every choice:

```text
:synth --behavior-mode filter --length-model list-scalar-exact-cases --length-inputs arg0 --where len(result)=len(arg0) -- List Nat -> List Nat
```

That form remains useful for explicit model and role control, but it is too
long for the overwhelmingly common built-in-`List` case, and `len(...)` does
not look like either host language. The concise forms therefore make only the
defaults that a checked target can support conservatively. Everything else
continues to require the explicit command or a contract file.

## Leant defaults

The concise Leant envelope is:

```text
:synth --where LEAN-LENGTH-CLAUSE -- TYPE
```

The first standalone `--` terminates the unquoted clause. A bare goal remains
valid in prove mode or after `sorry`. The clause uses `List.length argN`,
`List.length result`, and, for a canonical pair result,
`List.length result.1` and `List.length result.2`.

After successful Lean translation:

- only physical `SlotArrow` domains count as candidate inputs;
- every exact unary nominal `List` arrow is observed in source order;
- other physical arrows are explicitly unobserved;
- an exact unary `List` result selects the scalar model;
- only canonical Lean `Prod` with two exact unary `List` components selects
  the binary-product model;
- the fixed identity is `List` / `List.nil` / `List.cons`;
- candidate cases use the exact zero/step policy, the precondition is true,
  and the provider-law set is empty.

An unsupported result or component fails closed. The clause never infers a
custom spine, provider law, solver executable, or execution policy. A
provider-dependent candidate that cannot be prepared under the empty law set
is retained with its ordinary preparation refusal.

## Djex defaults

The standalone Djex REPL owns its own Haskell-shaped syntax and runtime:

```text
:set length-z3 /absolute/path/to/z3 [SHA256HEX]
:exference --where length result == length arg0 -- [a] -> [a]
```

The policy line can instead live in `.djexrc`, making each query a one-liner.
For the checked built-in-list target, the REPL derives the scalar or pair model
and observes eligible list inputs in source order. Pair projections use
`length (fst result)` and `length (snd result)`. The parser accepts only its
closed arithmetic/relation grammar; it does not evaluate arbitrary Haskell.

Exference currently supplies the source-typed graph required for behavioral
assessment. A Djinn-only constrained query fails closed. Under `:compare`, the
Djinn lane is labeled unavailable while the Exference lane is assessed; Djex
never silently switches backends or runs Djinn unconstrained.

## Authority and lifetime

In Leant, concise parsing has precedence only for an exact leading `--where`.
Longer lookalikes and option-looking text after the delimiter remain opaque
Lean goal text. Main resolves the goal, obtains literal filter permission from
the already activated startup mode, enters the bounded Djex parser, reports
the command scope, translates with the existing universe retry, resolves the
checked target defaults, and then opens exactly one command-local nominal
assessment context. The same context and counterexample bank span every
ordinary, provider, excluded-middle, and double-negation lane and both
progressive batches. Nothing enters `ReplState`, history, or snapshots.

In Djex, `:set length-z3` owns the pure execution-policy seal. The query then
uses the standalone REPL's normal typed Exference request and live Length
assessment. Only a fresh counterexample receipt replayed against the exact
candidate can remove it. Raw `sat`, `unsat`, and `unknown` statuses have no
rejection authority in either REPL.

## Checkpoints

- Djex `e7a69077` activated the standalone checked runtime and `359f0273`
  documented it.
- Djex `22ccf955` added the nominal Lean-shaped parser while retaining the
  Haskell and compact surfaces.
- Leant `4249899` added concise command ownership, target-derived defaults,
  and Main activation against Djex `22ccf955`.
- Leant `a605f2b` characterized the new defaults, refusals, opacity, parser
  precedence, and context lifetime.

The two repositories remain independently useful and independently
published. Leant consumes Djex's checked semantic library through its pinned
submodule, while Djex's standalone REPL does not depend on Leant.

## Validation

The Djex checkpoint passed its 91 CLI cases, all 456 Length cases after adding
the Lean-shaped parser, strict all-target build, Cabal check, and documentation
parsing. The Leant checkpoint passed 27 focused inline cases, all 481 unit
cases, the strict all-target build, Cabal check, and whitespace checks. The
existing transcript bank is replayed without update because the additive
leading `--where` path must not change any established command transcript.

## Deliberate exclusions

This checkpoint does not add automatic Z3 discovery, implicit unsafe policy
activation, arbitrary host-language evaluation, custom datatype inference,
provider-law inference, persisted behavioral state, extra synthesis batches,
semantic signatures, typed sketches, or a CEGIS fixpoint. Those require their
own authority and completeness designs rather than more command shorthand.

Current reference material:

- [Leant README](../../README.md#usage)
- [Leant Length ranking reference](../length-ranking.md#host-native-shorthand-and-djex-repl-parity)
- [Leant synthesis internals](../synth-internals.md#concise-lean-native-defaults)
- [Djex REPL guide](../../lib/Djex/docs/repl.md#behavioral-constraints)
- [Djex semantic foundation](../../lib/Djex/docs/semantic-foundations.md#host-language-repl-surfaces)
