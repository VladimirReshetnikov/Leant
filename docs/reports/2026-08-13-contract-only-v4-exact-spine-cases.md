# Contract-only v4 exact spine cases

Date: 2026-08-13

## Outcome

Leant's command-local Length contract now has an explicit version 4 grammar
for the single nonempty candidate-case shape supported by Djex's finite-spine
model. The root format and three root fields remain unchanged. Version 4
retains version 3's modulo expressions and required target-role vector, and
adds one required field:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 4,
  "contract": {
    "spine": {
      "family": "List",
      "zero": "List.nil",
      "step": "List.cons"
    },
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "exact-spine-zero-step-v1",
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["literal", 0]],
    "providerLaws": []
  }
}
```

No other case-policy value is admitted. In particular, version 4 cannot be
used as an implicit spelling of the legacy policy. Contract-only versions
1--3 and the startup configuration reject `candidateCasePolicy` as an unknown
field and retain their exact historical case-rejecting behavior.

## Closed version and failure order

`Leant.Synth.Length.Configuration.File` remains the single nested-contract
decoder owner. Its closed grammar choices now mean:

- version 1: compatibility expressions, no target roles, cases rejected;
- version 2: positive-literal modulo, no target roles, cases rejected;
- version 3: modulo and required target roles, cases rejected; and
- version 4: modulo, required target roles, and the exact zero/step policy.

Version 4 decodes the target-role array before the case policy and decodes the
case policy before either formula. Missing or malformed roles therefore retain
their earlier precedence, while a missing, mistyped, or unknown policy cannot
be hidden behind malformed behavioral syntax. Errors retain only the closed
field and failure vocabulary; rejected private strings are not preserved.

The decoded `LeanLengthContract` owns the case choice beside its existing
passive assertions. The file version itself is erased. No execution path,
digest, timeout, artifact, response, evaluation, solver, or replay authority
enters the contract.

## Independent graph and semantic checks

The case policy is never inferred from a candidate. A successful handoff
requires two independent authorities:

1. Exference's expression checker must retain a typed graph for a complete
   direct case over a recursive two-constructor spine with one zero-field
   constructor and one two-field constructor, exactly one of whose fields is
   the recursive spine.
2. Djex's exact-case Length sealer freshly binds that graph to the session's
   contract-resolved spine schema and rejects every other case shape.

Leant resolves the exact family and constructor identities from the retained
translation provenance. It does not translate `List.nil` or `List.cons` by
spelling convention. The Handoff policy matrix is explicit:

| Contract policy | Target roles | Session/problem path |
|---|---|---|
| cases rejected | absent | legacy sealers |
| cases rejected | present | role-aware sealers |
| exact zero/step | present | exact-case session and problem sealers |
| exact zero/step | absent | fail closed before session construction |

The separately checked contract always uses the role-aware entrance when a
role vector is present. Ordinary policies cannot acquire case behavior merely
because the candidate graph happens to contain a supported case.

## Accepted renderer association

One typed graph may have more than one valid Lean presentation. The verified
variant already retains its exact renderer ordinal, exact text, typed
candidate, and complete renderer provenance. Handoff now reruns that same
renderer, selects the recorded ordinal without converting the bounded
`Natural`, and requires the rerendered text to equal the callback-accepted
text. A missing ordinal or changed text fails closed.

This replaces the stricter single-alternative requirement and deletes its dead
ambiguity refusal. It does not associate semantics by text alone: sibling
variants, detached graphs, display ordinals, or another candidate remain
insufficient. The accepted variant still has to carry the exact opaque origin
which produced the rerendered list.

## Length interpretation and Z3 boundary

For an observed input length `n`, the admitted constructor case interprets:

- the zero branch under `n = 0`;
- the step branch under `n /= 0`;
- the recursive field as `n monus 1`; and
- the payload field as an opaque non-inspectable token.

The candidate result is a checked `LengthIf` over those branch expressions.
Provider authority is the canonical union of laws reached by both branches,
not only the concrete branch selected by one replay input. Payload demand,
unsupported patterns, incomplete or repeated alternatives, wrong result or
scrutinee spines, and every other nonempty case fail closed.

The result then follows the existing typed query and Z3 pipeline. The focused
production-path fixture synthesizes a real Exference `List Nat -> List Nat`
zero/step rebuild case, accepts one renderer variant through a deterministic
test callback, seals it through the version 4 handoff, and obtains one compact
SMT input. The callback does not invoke Lean elaboration. A hand-authored,
decoded model assigning that input length 3 is independently replayed to
candidate result 3 and then associated with the exact behavioral problem. The
fake live worker exercises the same protocol, query-first replay gate, and
stable counterexample demotion; it is not evidence that a real Z3 installation
solved this particular formula.

## Compatibility and trust boundary

The startup file remains version 1. Contract-only versions 1--3 keep their old
grammar, case rejection, and singleton/ordinal-zero renderer association.
Version 4 adds its explicit JSON field but changes no process policy, solver
protocol, SMT-LIB wire grammar, response decoder, solver status meaning,
evidence type, ranking algorithm, presentation association, or command
lifetime. It alone admits retained-ordinal association for a multi-alternative
exact renderer and selects an already versioned Djex semantic policy for one
command-owned contract.

The model says nothing about Lean purity, totality, termination, strictness,
effects, infinite values, source evaluation, or observational equivalence. It
does not prove provider laws. A replayed counterexample is bounded,
model-relative ranking evidence under the exact asserted contract; it is not a
Lean proof, a Z3 certificate, or permission to prune a candidate.
