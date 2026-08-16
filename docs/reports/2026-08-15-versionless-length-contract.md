# Versionless command-local Length contract

## Status and scope

This checkpoint replaces Leant's historical contract-only versions 1 through 6
with one current schema. Like every dated report, it is a non-normative record
of the change; the current reference is
[`docs/length-ranking.md`](../length-ranking.md), backed by
`Leant.Synth.Length.Contract.File`.

Leant is experimental and has no contract-file compatibility commitment. The
reset intentionally provides no migration decoder, version fallback,
deprecation period, or aliases for the former numeric roots. Git history and
the earlier dated reports retain those shapes as engineering history. Their
version-routing and API statements no longer describe the current executable.

This changes the passive command-local contract entrance only. It does not
change the startup execution policy, Djex's checked scalar or binary-product
semantics, solver protocol, replay boundary, ranking order, or evidence
authority.

## One current root

The format literal remains:

```text
leant-finite-list-spine-length-contract
```

The root has exactly three required members:

```text
format
rankingDomain
contract
```

There is no `version` member. `rankingDomain` accepts exactly the
case-sensitive literals `scalar` and `binary-product`. It is the sole domain
discriminator:

- `scalar` selects `LeanLengthScalarContractSelection` and the scalar result
  variable `["result"]`;
- `binary-product` selects `LeanLengthSpinePairContractSelection` and the
  separately typed result variables `["result", "first"]` and
  `["result", "second"]`.

Neither selected contract contains `resultShape`. That redundant field was
removed from both the command-local and startup pair grammars. A domain is
never inferred from the Lean goal, result syntax, or candidate.

## Scalar example

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "rankingDomain": "scalar",
  "contract": {
    "spine": {
      "family": "List",
      "zero": "List.nil",
      "step": "List.cons"
    },
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": ["truth", true],
    "postcondition": [
      "equal",
      ["result"],
      ["sum", [
        ["modulo", 2, ["input", 0]],
        ["quotient", 2, ["input", 0]]
      ]]
    ],
    "providerLaws": []
  }
}
```

## Binary-product example

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "rankingDomain": "binary-product",
  "contract": {
    "spine": {
      "family": "List",
      "zero": "List.nil",
      "step": "List.cons"
    },
    "targetArgumentRoles": ["observed-spine"],
    "candidateCasePolicy": "cases-rejected",
    "precondition": ["truth", true],
    "postcondition": [
      "all",
      [
        ["equal", ["result", "first"], ["input", 0]],
        ["equal", ["result", "second"],
          ["quotient", 2, ["input", 0]]]
      ]
    ],
    "providerLaws": []
  }
}
```

The examples exercise the two domain-specific result vocabularies while using
the same exact nested field set and limits.

## One parse and exact rejection precedence

`decodeLengthContractFile` calls the bounded JSON parser exactly once. It does
not first try a scalar decoder, inspect an unsupported-version sentinel, parse
again, or retry as a pair document. After bounded JSON admission, its semantic
order is:

1. require a root object;
2. require `format`, require a string, and check the exact literal;
3. require `rankingDomain`, require a string, and check its exact literal;
4. require the exact three-member root, reporting the first unexpected member
   before any still-missing member;
5. require `contract` to be an object; and
6. invoke exactly the decoder selected by `rankingDomain`.

JSON member order does not alter this demand order. Duplicate keys, malformed
UTF-8, excessive input, nesting, node counts, strings, numbers, and collection
sizes still fail in the shared bounded parser before semantic decoding.

The public rejection vocabulary follows that order exactly. Missing root
members use `LengthContractFileMissingRootField`; non-string format/domain and
non-object contract values use `LengthContractFileFieldTypeMismatch`; a wrong
format uses `LengthContractFileUnsupportedFormat`; a domain literal other than
the two current values uses `LengthContractFileFieldValueRejected` with
`LengthContractFileRankingDomainField`; and closed-root failure uses
`LengthContractFileUnexpectedRootField`. A selected nested failure is wrapped
once in `LengthContractFileContractRejected`.

An untouched historical root fails for missing `rankingDomain`. Adding a valid
domain while retaining `version` reaches exact-root validation and fails for an
unexpected member. A historical pair contract containing `resultShape` fails
the selected nested exact-object check. None is migrated or assigned a nearby
current meaning.

## Exact nested grammar

Both domain-selected contract objects have exactly six required fields:

```text
spine
targetArgumentRoles
candidateCasePolicy
precondition
postcondition
providerLaws
```

The exact-object check reports an unexpected field before a missing field.
After shape admission, the fields are validated in the order above. The spine
object itself contains exactly `family`, `zero`, and `step`. Contract names,
field names, enum values, and syntax tags are case-sensitive.

Scalar expressions admit `["input", n]` and `["result"]`. Binary-product
expressions admit `["input", n]`, `["result", "first"]`, and
`["result", "second"]`. Provider transfers use `["argument", n]`. The current
shared expression grammar also includes:

```text
["literal", natural]
["sum", [expression, ...]]
["scale", natural, expression]
["modulo", positiveLiteral, expression]
["quotient", positiveLiteral, expression]
["monus", expression, expression]
["minimum", expression, expression]
["maximum", expression, expression]
["if", formula, expression, expression]
```

The shared formula grammar is:

```text
["truth", boolean]
["equal", expression, expression]
["at-most", expression, expression]
["not", formula]
["all", [formula, ...]]
```

Modulo and quotient are current in preconditions, postconditions, and provider
transfers for both result domains. Their divisors are validated before their
operands, must be nonzero, and remain within the 256-bit contract-literal
ceiling.

Leant retains the passive syntax. Djex lowers surviving modulo and quotient to
private deterministic Euclidean quotient/remainder witnesses in QF_LIA. It
emits no SMT-LIB `mod` or `div`, does not request private witnesses with
`get-value`, and independently recomputes Natural modulo or quotient during
replay.

## Explicit roles and case authority

`targetArgumentRoles` is always present and contains only `observed-spine` or
`unobserved-target`, with at most eight source-ordered entries. Handoff requires
the vector to match every physical target argument after leading quantifiers.
Observed positions receive compact Length input indices in source order.

Provider-law `argumentRoles` remain a different physical-argument vocabulary:
each entry is `spine` or `unobserved`, and `["argument", n]` retains its physical
provider index. Target-role compaction never renumbers provider transfers.
Each provider-law object has exactly `name`, `argumentRoles`, and `transfer`;
the file admits at most 256 laws and at most 16 roles per law.

An unobserved target is only a non-inspectable token. Calling, spine-observing,
or destructuring it fails candidate preparation. The role proves nothing about
inhabitance, evaluation, purity, totality, parametricity, strictness, or effects.

`candidateCasePolicy` is likewise always explicit and accepts exactly:

```text
cases-rejected
exact-spine-zero-step-v1
```

Case rejection preserves the singleton, renderer-ordinal-zero rule. Exact
zero/step authority requires the independently retained complete case over the
configured recursive spine and selects its exact accepted renderer ordinal.
Neither policy is inferred, proves source equivalence or termination, or grants
pruning authority. Because roles are mandatory, the former
`LengthHandoffExactCasePolicyRequiresTargetRoles` state is no longer
constructible and has been removed.

## Public API reset

The command-local route now has one canonical name at each layer:

```haskell
decodeLengthContractFile
  :: ByteString
  -> Either LengthContractFileError LeanLengthContractSelection

loadLengthContractFile
  :: LengthContractFileRequest
  -> IO (Either LengthContractFileLoadError LeanLengthContractSelection)

explicitLengthAssessmentRequest
  :: ExplicitLengthAssessmentPermission
  -> LeanLengthContractSelection
  -> LengthAssessmentRequest
```

Main calls those three generalized entrances. The removed exported names and
error identities are:

- `lengthContractFileVersion`, `lengthContractFileModuloVersion`,
  `lengthContractFileTargetRolesVersion`,
  `lengthContractFileExactCaseVersion`, `lengthContractFileQuotientVersion`,
  and `lengthContractFileSpinePairVersion`;
- `LengthContractFileVersionField`, `LengthContractFileIntegerValue`, and
  `LengthContractFileUnsupportedVersion`;
- `decodeLengthContractSelectionFile`;
- `loadLengthContractSelectionFile`;
- `explicitLengthAssessmentSelectionRequest`;
- `decodeLeanLengthContractValueV2`, `decodeLeanLengthContractValueV3`,
  `decodeLeanLengthContractValueV4`, and `decodeLeanLengthContractValueV5`;
- `decodeLeanLengthSpinePairContractValueV5`, replaced by
  `decodeLeanLengthSpinePairContractValue`;
- `LengthRankingConfigurationResultShapeField`; and
- `LengthHandoffExactCasePolicyRequiresTargetRoles`.

The unsuffixed decoder, loader, and request names remain, but their former
scalar-only signatures are replaced by the nominal selection signatures shown
above. The private `LengthContractGrammar` dispatcher,
`decodeLengthContractSelectionFileSpinePairV6` second parse, and per-version
shape tables are deleted rather than retained behind aliases.

`LeanLengthContract` and `LeanLengthSpinePairContract` now retain strict explicit
role lists rather than optional role vectors. No compatibility alias remains.

## CLI lifetime and authority

The command grammar remains:

```text
:synth --length-contract ABSOLUTE-PATH -- TYPE
```

The exact option spelling and standalone delimiter are mandatory. Everything
after the delimiter remains opaque Lean goal text. Main first requires an
already activated Length-ranking policy; disabled mode rejects the request
before path admission or file IO. It then admits and reads the explicitly named
absolute path once, before goal translation, with the established 5,000-ms
interruption budget and 262,144-byte JSON ceiling.

The decoded selection replaces only the startup-fixed passive contract for
that command. The activated executable, digest decision, solver/resource and
host deadlines, artifact policy, response/evaluation/replay limits, ordering,
simplification, and usable-work ownership cannot be replaced. The same opaque
request is threaded through ordinary synthesis, universe retry, provider
widening, classical fallback, and every verification/presentation batch. It
never enters `ReplState`, `ParsedGoal`, history, snapshots, environment
companions, or a cache, and the file is not reopened by later lanes. The next
command returns to the startup contract unless it names another file.

Decoding and request association launch no solver and mint no evidence. Raw
`sat`, `unsat`, and `unknown` remain heuristic. Only an independently replayed
counterexample or completed bounded validation can affect stable ordering;
nothing is pruned. Provider laws remain caller-supplied assumptions, not proofs
about their Lean implementations.

## Historical reports and documentation precedence

Earlier contract-only v2, v3, v4, v5, binary-product, and one-shot reports
remain useful explanations of how modulo, roles, exact cases, quotient, pair
semantics, and command-local lifetime landed. Their numbered roots and old API
names are historical snapshots, not accepted alternatives.

For the current tree, read sources in this order:

1. implementation and tests;
2. [`docs/length-ranking.md`](../length-ranking.md) and
   [`docs/synth-internals.md`](../synth-internals.md);
3. this report; and
4. earlier dated reports as non-normative history.
