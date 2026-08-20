# Inline Length where-clause runtime activation

Date: 2026-08-20

## Outcome

Leant now consumes the previously passive inline Length command surface in
production. One `:synth` command can select a fixed exact-case list model,
declare the physical source-arrow inputs whose spines are observable, and give
one bounded ASCII postcondition without a JSON contract file:

```text
:synth --behavior-mode filter --length-model list-scalar-exact-cases|list-binary-product-exact-cases --length-inputs arg0[,argN...] --where CLAUSE -- TYPE
```

The bar displays two alternative literal model tokens; it is not part of one
accepted command. The clause is unquoted and ends at the standalone `--`.
Quote characters are clause input and the bounded parser rejects them. The
form requires literal `--behavior-mode filter`, cannot be combined with
`--length-contract`, and reuses the already activated startup execution
policy. It supplies no process-launch, pin, solver, replay, or rejection
authority by itself.

The production activation landed as
`e078ca9168b71f8d8dab5cbe87d115384be855d5` (`Activate inline Length
constraints in synth`). Its runtime characterization landed as
`0425ad9be5bcb8f8e3612b711e2fff94ad1c13be` (`Characterize inline Length
runtime activation`). The initial reconciliation baseline inspected for this
report is Leant `260d36d1dc2578ce7e470171c8591137569e455f`, with the Djex submodule at
`39c95a9b20e15f4e96c2b1447853943c98220c98`. The final Stage 1 parent is
intentionally not frozen here; it is assigned only after the documentation is
merged with any later non-overlapping mainline advance.

## Fixed syntax and semantic profile

`Leant.Synth.Length.Command` recognizes the inline form before delegating
non-inline input to the established command parser. Structural validation owns
option order, repetition, required literal filter mode, and the mutual
exclusion of file and inline contract sources. The model token is exactly
`list-scalar-exact-cases` or `list-binary-product-exact-cases`.

`--length-inputs` is one nonempty comma-separated token containing strictly
increasing numeric `argN` indices from `arg0` through `arg7`. Leading zeroes
are accepted as numeric aliases, so alias duplicates and descending aliases
are rejected after decoding. Gaps are valid, and a listed input need not occur
in the clause. Every clause `len(argN)` reference must be listed and lie within
the translated physical arity. These are physical source-arrow positions.
After Lean translation, Main counts only `SlotArrow` entries in the fragment
spine; universal, instance, and contextual slots do not enter that number.
Listed arrows become observed roles compacted in source order and omitted
arrows become unobserved roles.

The Djex parser admits one ASCII relation over natural literals,
`len(argN)`, scalar `len(result)`, product `len(result.first)` and
`len(result.second)`, linear arithmetic, direct-positive-literal division and
remainder, `min`/`max`, parentheses, and the six ordinary comparison operators.
It retains no source bytes. Admission is bounded at 16,384 UTF-8 bytes and 64
parser-nesting levels across parentheses, `len`, `min`, and `max`, in addition
to the existing Length syntax, formula, collection, literal, and input limits.
Parse and elaboration errors are closed and sanitized; diagnostics never echo
the clause.

Resolution expands exactly one of two profiles:

- fixed `List`, `List.nil`, and `List.cons` identities;
- scalar result or canonical binary `Prod` result, selected only by the model
  token;
- the complete explicit observed/unobserved target-role vector;
- the exact zero/step candidate-case policy;
- a true precondition and the parsed relation as postcondition; and
- an empty provider-law set.

No model, spine identity, result domain, role, case policy, provider law, or
execution permission is inferred from the clause or the translated Lean
target. Consequently a provider-dependent candidate that cannot be prepared
under the empty provider-law set is retained with its ordinary preparation
refusal. It is not a behavioral rejection.

## Authority and lifetime order

Main owns the complete order for the new entrance:

1. parse and structurally validate the inline command;
2. resolve the explicit goal or current prove/`sorry` goal source;
3. authorize literal filter mode against the activated startup policy;
4. parse the bounded clause;
5. emit the established inaccessible-hypothesis and premise-scope report;
6. translate the Lean target, including the existing universe retry;
7. count only physical `SlotArrow` entries and resolve the clause/profile;
8. construct exactly one authorized scalar or product assessment context; and
9. pass that context through every ordinary, provider, excluded-middle, and
   double-negation lane.

The filter authorization precedes clause parsing, so disabled assessment
refuses the request before parsing or IO. Translation and target association
precede context creation, so either failure creates no counterexample bank.
Once created, the one nominal context retains the existing progressive-batch
and cross-lane lifetime, and no request, clause, parsed source, role vector,
bank, result, or context enters `ReplState`, history, snapshots, or later
commands.

The established startup and contract-file entrances intentionally keep their
older order: `synthRun` opens their one assessment context before translation
and retains it through universe narrowing and all lanes. Activating the inline
entrance did not silently change that lifetime.

## Characterization

The active focused group retains the twenty pure structural/parser/profile
checks and adds the runtime-architecture boundary as its twenty-first case. It
pins inline-first dispatch, goal selection before authorization, literal
`LengthBehaviorFilter` permission, post-authorization bounded parsing,
translation/retry before resolution, `SlotArrow`-only arity, one post-resolution
context, reuse of `explicitLengthAssessmentRequest`, and absence of the inline
surface from lower Integration, Configuration, and Handoff layers.

Provider-free runtime fixtures cover both result domains:

- the scalar fixture distinguishes identity length from positive-spine
  increment under
  `len(result)=len(arg0)+min(len(arg0),1)`; and
- the product fixture distinguishes `(input,input)` from `(input,0)` under
  `len(result.first)+len(result.second)=2*len(arg0)`.

The tests activate a real request-scoped filter policy, compare startup,
inline, and later startup requests, and establish that neither contract choice
nor bank state sticks across commands.

## Verification evidence

At the reconciled baseline, the following strict gates passed:

- active inline Length group: 21/21;
- Integration group: 24/24;
- full Leant unit suite: 475/475;
- strict `cabal build all -j1 --ghc-options=-Werror`; and
- all 26 pinned-backend golden transcripts, byte-exact after the runner's
  comparison-only queue-telemetry normalization.

The inline change required no checked-in golden fixture update. The later
telemetry normalization does not regenerate or alter checked-in expected
transcript bytes: only the numeric queue total is normalized symmetrically,
while any label, reason, semantic-line, or removal drift still fails. Cabal
package checks and whitespace/diff checks also passed at the reconciliation
boundary.

## Artifact evidence

Stage 1 updates source documentation only. Every maintained PDF remains at its
pre-update byte sequence and the six current walkthrough snapshot pins remain
unchanged. Rebuilt PDF hashes, page counts, source/archive checks, and visual
inspection evidence are deliberately pending the separate Stage 2 artifact
commit.
