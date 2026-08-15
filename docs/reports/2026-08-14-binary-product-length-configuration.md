# Binary-product Length configuration

Date: 2026-08-14

> **Later 2026-08-14 follow-up.** The opaque reusable policy now also has
> separate programmatic applicable-domain validation and non-vacuous preference
> choices for both scalar and pair ranking. The closed startup and contract-
> only schemas remain exactly v1--v6 and cannot enable either choice. See the
> [directly bounded applicable-domain report](2026-08-14-directly-bounded-length-applicable-domain.md).
>
> **Later 2026-08-14 follow-up.** Startup v6 is the pair successor which retains
> v4's operational and contract grammar and additionally requires
> `"boundedPositiveOrdering": "prefer-non-vacuous"`. Scalar v5 supplies the same
> preference with full scalar contract grammar v5. Existing versions remain
> exact and neutral. The opaque policy now retains that preference orthogonally
> to its execution, evaluation, input-box, and origin-probe fields. See the
> [non-vacuous bounded-positive ordering report](2026-08-14-non-vacuous-bounded-positive-ordering.md).

## Outcome

Leant now exposes its nominal canonical-`Prod` Length runner through Main's
existing explicit configuration entrances. Startup ranking configuration
version 4 selects the pair domain for the process-fixed contract. Contract-only
version 6 selects the pair domain for one `:synth` request. Neither adds a CLI
option, infers a contract from a Lean type, or turns a structurally pair-shaped
candidate into behavioral authority.

The process and behavioral selections remain separate. At this checkpoint, a
single opaque `LengthRankingPolicy` owned checked execution, evaluation,
optional input-box, and optional origin-probe policy. The later programmatic
follow-up above adds its two orthogonal choices without changing this report's
file schemas. A passive
`LeanLengthContractSelection` chooses either a scalar `LeanLengthContract` or a
nominal `LeanLengthSpinePairContract`. Dispatch then calls exactly one
domain-specific occurrence-sealed assessor; scalar and pair queries,
observations, receipts, failures, rankings, and presentation remain different
types.

## Contract-only version 6

The root format remains exactly
`leant-finite-list-spine-length-contract`. Version 6 has the same closed root
fields as versions 1--5: `format`, `version`, and `contract`. The version is the
domain selection, so there is no second `contractDomain` field which could
disagree with it.

A complete unary example is:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 6,
  "contract": {
    "resultShape": "binary-prod-spines-v1",
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
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

The pair contract object has exactly these fields:

1. `resultShape`, whose only value is `binary-prod-spines-v1`;
2. `spine`, with the established exact `family`, `zero`, and `step` names;
3. `targetArgumentRoles`, a required source-ordered vector of
   `observed-spine` or `unobserved-target`;
4. `candidateCasePolicy`, exactly `cases-rejected` or
   `exact-spine-zero-step-v1`;
5. `precondition`;
6. `postcondition`; and
7. `providerLaws`.

After bounded JSON parsing and the root format/version/exact-field gates, that
is also the semantic validation order. JSON object member order itself is not
significant. Missing, unknown, wrongly typed, or out-of-bound content fails
closed through the existing sanitized vocabulary.

The formula and arithmetic grammar retains scalar version 5's closed forms,
including positive-literal Natural modulo and quotient and the existing
provider-law grammar. The contract-variable vocabulary is nominally different:
only `["input", n]`, `["result", "first"]`, and
`["result", "second"]` are admitted. Provider transfers keep their established
provider-variable vocabulary. The result-shape literal is therefore an
additional closed schema check, not permission to reinterpret scalar result
variables or generic products.

The established `decodeLengthContractFile` remains literally the scalar
versions 1--5 decoder and rejects version 6. The additive
`decodeLengthContractSelectionFile` delegates those old versions to that
decoder and wraps their result as the scalar selection; only v6 takes the pair
path. `loadLengthContractSelectionFile` adds the same generalized dispatch at
the already shared bounded acquisition boundary. The old scalar decoder and
loader keep their types, errors, grammar, and failure precedence.

## Startup version 4

The root format remains exactly
`leant-live-length-ranking-configuration`. Version 4 retains version 3's full
operational shape and replaces only its embedded scalar compatibility contract
with the pair contract above. A complete example is:

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 4,
  "executionAdmission": {
    "executablePathCharacters": 4096,
    "policyFingerprintBytes": 262144
  },
  "execution": {
    "executablePath": "/absolute/path/to/z3",
    "expectedExecutableSha256": null,
    "solverTimeoutMilliseconds": 1000,
    "solverResourceLimit": 100000,
    "hostDeadlineMilliseconds": 1500,
    "artifactPolicy": "input-values-after-satisfiable",
    "responseLimits": {
      "bytes": 65536,
      "nestingDepth": 64,
      "nodes": 4096,
      "tokenBytes": 4096,
      "integerBits": 4096
    }
  },
  "evaluation": {
    "assignmentValueBits": 4096,
    "intermediateValueBits": 4096
  },
  "inputBoxValidation": {
    "inclusiveInputMaximums": [3],
    "maximumAssignments": 4
  },
  "counterexampleProbe": "origin-before-live",
  "contract": {
    "resultShape": "binary-prod-spines-v1",
    "spine": {"family": "List", "zero": "List.nil", "step": "List.cons"},
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

The closed v4 root fields are `format`, `version`, `executionAdmission`,
`execution`, `evaluation`, `inputBoxValidation`, `counterexampleProbe`, and
`contract`. After the common root gates, semantic validation is deliberately:

1. execution admission;
2. execution configuration;
3. evaluation limits;
4. finite input-box validation;
5. the exact `origin-before-live` probe selection; and
6. the pair contract in the seven-field order above.

Thus a poisoned later contract cannot preempt an earlier operational failure.
The input box remains explicit and source ordered; the probe contains no
arity, input vector, solver status, receipt, or verdict. Activation still
separately requires a digest pin unless the caller explicitly permits an
unpinned executable. It inspects the sealed execution policy, not the lazy
contract, and launches no worker.

`decodeLengthRankingConfigurationFile` remains literally the scalar v1--v3
decoder and rejects v4. The generalized
`decodeLengthAssessmentConfigurationFile` delegates those old versions to the
old decoder and wraps their scalar contracts; only v4 decodes a pair contract.
It returns an opaque `DisabledLengthAssessmentConfiguration`, which
`activateLengthAssessmentConfiguration` releases only after the unchanged pin
policy decision. `loadLengthAssessmentConfigurationFile` supplies the matching
bounded acquisition entrance. Existing scalar APIs remain available and do
not silently broaden their accepted version set.

## Main entrance and lifetime

The command lines are unchanged. For the unpinned illustrative startup file
above, explicit invocation is:

```text
leant --length-ranking-config /absolute/path/pair-ranking-v4.json \
  --length-ranking-allow-unpinned
```

With a lowercase 64-hex executable expectation in the file, omit the explicit
unpinned relaxation. No option discovers a solver, configuration, or contract.
The existing path admission, one-descriptor bounded read, JSON ceiling,
sanitized cleanup reporting, and POSIX/Windows behavior apply unchanged.

The startup v4 selection is process fixed. The existing command-local grammar
can replace only its passive contract selection for one request:

```text
:set synth-engine exference
:synth List Nat → Prod (List Nat) (List Nat)
:synth --length-contract /absolute/path/pair-contract-v6.json -- List Nat → Prod (List Nat) (List Nat)
```

The standalone `--` remains mandatory. Main authorizes the explicit request
from the activated policy before it admits or opens the contract path, threads
the decoded selection through every retry and synthesis lane for that command,
and retains no selection in `ReplState`, history, snapshots, or a cache. The
next command without `--length-contract` returns to the startup-fixed
selection. `explicitLengthAssessmentSelectionRequest` is the generalized
integration wrapper; the established scalar request wrapper remains a
compatibility entrance.

Main dispatches presentation from the same nominal assessment result.
`lengthAssessmentSpinePairRanking` and
`lengthAssessmentSpinePairPostVerificationResult` expose pair projections
without casting them to scalar results. Candidate text and pair evidence remain
owned by the same occurrence-sealed post-verification result.

## Product ranking and authority

Selecting v4 or v6 does not infer suitability from the requested Lean type.
Every callback-verified candidate must independently pass the exact normalized
canonical-`Prod` provenance gate, both configured-spine field checks, renderer
and family correspondence, provider resolution, interpretation-policy sealing,
and pair-query preparation. `And`, `PProd`, a structural generic pair, a scalar
result, a nested product, or a product with a non-spine field remains
ineligible. A passive JSON assertion cannot manufacture typed Exference
authority.

For each eligible pair candidate, the configured v4 order is:

1. replay at most four newest-first pair-batch MRU input vectors;
2. after those miss, run the exact query-owned all-zero origin probe;
3. after that misses, issue the live pair query;
4. replay and associate its observation against the exact pair query before
   inspecting status; and
5. only for counterexample-free live `unsat`, independently traverse the
   configured finite input box.

Only a freshly evaluated and associated pair counterexample enters the stable
demoted partition and supplies an MRU input vector. Complete finite-box
traversal is neutral bounded-positive information. Status-only `sat`, `unsat`,
and `unknown` remain neutral heuristics. Structured session, live-query,
association, replay, origin, or box failure restores the admitted batch in
original order as unassessed; pure candidate-local preparation refusals remain
local. Nothing is pruned.

The common policy and worker capability grant only process/evaluation and
QF_LIA transport readiness. Pair contracts, checked problems, query/run and
observation identities, counterexample and positive receipts, failures,
rankings, MRU state, and presentation remain nominally pair-specific. Evidence
is model-relative under the explicit finite-spine model and any assumed
provider laws. It is not Lean execution, a kernel theorem, a universal proof,
provider-law validation, source equivalence, Z3 attestation, or proof of
termination.

## Compatibility boundary

This checkpoint is additive at new generalized entrances:

- startup v1 remains the exact historical scalar compatibility grammar;
- startup v2 remains scalar and adds only its required finite input box;
- startup v3 remains scalar and adds only its required origin selection over
  v2;
- contract-only v1--v5 retain their exact scalar grammars and behavior;
- the established scalar decoders and loaders reject v4/v6 rather than
  broadening in place; and
- the CLI option and command spellings, delimiters, default-disabled path, file
  lifetime, worker lifetime, and scalar presentation are unchanged.

Version 4 and version 6 are the only new domain selections. They do not add
automatic result-type dispatch, a generic SMT interface, durable policy or
contract state, cross-domain evidence conversion, or a second session budget.
