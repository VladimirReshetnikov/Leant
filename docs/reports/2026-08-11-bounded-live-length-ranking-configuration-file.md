# Bounded live Length ranking configuration file

Date: 2026-08-11

## Outcome

`Leant.Synth.Length.Configuration.File` defines one closed JSON format for the
explicit live Length-ranking policy:

- `format` is exactly `"leant-live-length-ranking-configuration"`;
- `version` is the integral JSON number `1`; and
- every object has exactly the fields listed below. All fields are required.

The pure `decodeLengthRankingConfigurationFile` function accepts a strict
`ByteString` and returns either a sanitized structured error or an opaque
`DisabledLengthRankingConfiguration`. It performs no IO. The later CLI
integration supplies an explicit bounded file loader, but still adds no default
path, executable discovery, path normalization, environment lookup, autoload
rule, or solver launch during decoding.

The disabled wrapper retains only the completed opaque configuration. It does
not copy a Boolean from the raw JSON digest field. Later activation derives
digest-expectation presence from the sealed Djex execution policy, so the
activation decision cannot drift from the policy it releases.

A document has this exact version-1 object shape (the concrete values are an
illustration, not defaults selected by Leant):

```json
{
  "format": "leant-live-length-ranking-configuration",
  "version": 1,
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
  "contract": {
    "spine": {
      "family": "List",
      "zero": "List.nil",
      "step": "List.cons"
    },
    "precondition": ["truth", true],
    "postcondition": [
      "at-most",
      ["result"],
      ["sum", [["input", 0], ["literal", 1]]]
    ],
    "providerLaws": [
      {
        "name": "Demo.provider",
        "argumentRoles": ["spine", "unobserved"],
        "transfer": ["argument", 0]
      }
    ]
  }
}
```

`expectedExecutableSha256` is either `null` or exactly 64 lowercase
hexadecimal characters. `artifactPolicy` is exactly `"status-only"` or
`"input-values-after-satisfiable"`. Each provider argument role is exactly
`"spine"` or `"unobserved"`. Strings are compared after JSON escape decoding;
there is no alternate decoded value or case folding.

## Closed contract grammar

Every expression or formula is a JSON array whose first element is a string
tag and whose remaining elements have the exact arity shown here. An unknown
tag, wrong arity, wrong value kind, negative natural, or non-integral JSON
number is rejected.

| Form | Tagged JSON shape |
| --- | --- |
| contract input | `["input", index]` |
| contract result | `["result"]` |
| provider argument | `["argument", index]` |
| natural literal | `["literal", value]` |
| sum | `["sum", [expression, ...]]` |
| scale | `["scale", natural, expression]` |
| truncated subtraction | `["monus", expression, expression]` |
| minimum / maximum | `["minimum", expression, expression]` / `["maximum", expression, expression]` |
| conditional expression | `["if", formula, expression, expression]` |
| truth value | `["truth", boolean]` |
| equality / ordering | `["equal", expression, expression]` / `["at-most", expression, expression]` |
| negation | `["not", formula]` |
| conjunction | `["all", [formula, ...]]` |

Only `input` and `result` variables are legal in the precondition and
postcondition. Only `argument` variables are legal in provider transfers, and
an argument index must also be smaller than that law's `argumentRoles` length.
Although the file grammar can represent `result` in either contract formula,
Djex's later candidate-specific contract check rejects it in a precondition.
The decoder does not infer roles, provider laws, spine names, or a contract
from a goal or live environment.

## Hard parser limits

The authority-bearing format does not use the older permissive backend JSON
codec. `Leant.Json.Bounded` first checks the complete strict byte string, then
decodes strict UTF-8 and parses one complete JSON value under these fixed
limits:

| Resource | Maximum |
| --- | ---: |
| complete input | 262,144 bytes |
| nesting depth | 133 |
| JSON value nodes | 32,768 |
| members in one object | 32 |
| elements in one array | 257 |
| decoded object-key size | 64 UTF-8 bytes |
| decoded string-value size | 16,384 UTF-8 bytes |
| decoded string-value length | 4,096 Unicode scalar values |
| JSON number token | 80 bytes |

The parser rejects a UTF-8 byte-order mark, invalid UTF-8, raw control
characters, invalid escapes, lone surrogates, invalid JSON numbers, trailing
content, and duplicate object keys. Duplicate rejection happens while parsing,
before schema lookup, so there is no first-wins or last-wins interpretation.
Integral numbers retain exact arbitrary-precision values. Fractional or
exponent-bearing numbers retain their exact bounded token but cannot satisfy an
integral configuration field; they are never rounded through floating point.
Unknown object fields are also rejected rather than ignored.

The total-byte check occurs *after* the caller has acquired the strict
`ByteString`. It bounds decoding and retained parser state, not allocation or IO
performed by a reader. `Configuration.File.Acquire` owns the corresponding
maximum-plus-one bounded acquisition before passing retained bytes here. This
module does not claim that merely calling the decoder makes an unbounded read
safe.

## Hard semantic limits

The file does not carry `LengthLimits` and therefore cannot enlarge Leant's
candidate handoff authority. Its contract grammar pins the corresponding core
Djex `defaultLengthLimits` ceilings and adds separate Leant name and semantic
depth ceilings:

| Contract resource | Maximum |
| --- | ---: |
| contract inputs | 8 (`input` indices 0 through 7) |
| expression/formula syntax nodes | 1,024 |
| atomic formula clauses | 32 |
| terms in one `sum` | 64 |
| formulas in one `all` | 64 |
| provider laws | 256 |
| argument roles in one provider law | 16 |
| provider argument index | 15, and less than that law's role count |
| natural-literal width | 256 bits |
| semantic nesting depth | 64 |
| each spine or provider name | 256 Unicode scalars and 1,024 UTF-8 bytes |

The 1,024-node and 32-clause budgets are cumulative across the precondition
and postcondition. Provider transfers have a separate 1,024-node/32-clause
budget shared across all laws. The depth and collection limits apply to each
structural path or collection respectively.

The rest of `defaultLengthLimits` remains in the existing candidate-specific
handoff: 4,096 typed nodes and a 65,536-byte checked-problem fingerprint, as
well as the same 8-input, 1,024-syntax-node, 32-clause, 64-wide,
256-provider-law, 16-provider-argument, and 256-literal-bit ceilings. A file
cannot replace those limits. A syntactically valid contract is still only an
assertion; it can be refused later when checked against the exact verified
candidate, its typed graph, spine provenance, and provider assumptions.

## Hard operational-policy limits

Every operational number is explicit in the file and then constrained by a
fixed outer ceiling:

| Policy field | Maximum |
| --- | ---: |
| `executionAdmission.executablePathCharacters` | 4,096 |
| `executionAdmission.policyFingerprintBytes` | 262,144 |
| `execution.solverTimeoutMilliseconds` | 60,000 |
| `execution.solverResourceLimit` | 10,000,000 |
| `execution.hostDeadlineMilliseconds` | 65,000 |
| `execution.responseLimits.bytes` | 65,536 |
| `execution.responseLimits.nestingDepth` | 64 |
| `execution.responseLimits.nodes` | 4,096 |
| `execution.responseLimits.tokenBytes` | 4,096 |
| `execution.responseLimits.integerBits` | 4,096 |
| `evaluation.assignmentValueBits` | 4,096 |
| `evaluation.intermediateValueBits` | 4,096 |

Djex's ordinary validation still applies within those ceilings. The solver
timeout, resource limit, and host deadline must be positive; the host deadline
must exceed the solver timeout by at least 100 milliseconds. The executable
path must be nonempty, absolute, and fit the explicitly selected admission
limit. Response nesting/integer limits and both evaluation limits must be
nonnegative. The policy fingerprint must fit its explicitly selected admission
limit. No field is read from an environment variable or completed from a
default.

The response and replay limits do not combine into a batch deadline. The
ranking foundation still admits at most 64 candidates, prepares the complete
eligible batch before opening one lexical live session, and applies the host
deadline separately to each serial query. Djex's private lifecycle and cleanup
budgets remain separate as well.

## Validation order and sanitized failures

The decoder has a deterministic fail-closed order:

1. enforce the bounded-JSON byte limit, strict UTF-8 and complete JSON syntax;
2. require a root object, then validate `format`, then integral `version`;
3. once those two gates succeed, reject an unexpected root field before
   reporting any other missing root field;
4. validate `executionAdmission`, then `execution`, then `evaluation`, then
   `contract`;
5. for each exact nested object, reject an unexpected field before a missing
   field, and establish the complete field set before decoding its values;
6. within execution, schema-decode `responseLimits`, path, digest, timeout,
   resource limit, host deadline, and artifact policy in that order, then let
   Djex apply its semantic timeout, resource, deadline, path, digest, and
   fingerprint precedence;
7. retain that sealed execution configuration, then decode and retain Djex's
   sealed evaluation limits;
8. within the contract, validate the spine, precondition, postcondition, and
   provider laws in that order; and
9. assemble those already validated authorities and the lazy contract into the
   opaque compatibility configuration without rethreading raw sources through
   aggregate records or running either validation a second time.

JSON duplicate keys are rejected earlier than all schema checks. Errors retain
closed field/object/phase classifications and bounded numeric observations,
not unknown key text, tag text, source snippets, paths, digests, Lean names, or
solver output. Because successful execution and evaluation values are retained
directly, there is no separate post-validation assembly failure class.

## Disabled decoding and explicit activation

Successful decoding and validation still grant no permission to execute. The
result is opaque and disabled. A caller must make one subsequent explicit
choice with `activateLengthRankingConfiguration`:

- `RequirePinnedExecutable` succeeds only when
  `expectedExecutableSha256` supplied a valid non-null digest; or
- `PermitUnpinnedExecutable` visibly accepts either a pinned or unpinned
  policy.

The disabled value exposes only that activation operation; it does not expose
the retained path, digest, contract, or policy. Requiring a pin fails closed
for the sealed policy's absent classification. Permitting an unpinned
executable is a caller decision, never a decoder fallback. Activation itself
remains pure, does not inspect digest bytes, the contract, or the filesystem,
and does not start a worker. The present classification says only that the
policy retained an expectation; it does not say that a live executable matched
it.

Even a non-null digest is only an expectation for Djex's later pre-spawn
SHA-256 observation of the executable file. It is not attestation of the image
ultimately executed: portable direct spawn does not execute the descriptor
that was hashed, and the loader and shared libraries are outside the
observation.

## Authority and ranking behavior

Parsing, validation, and activation establish only a bounded policy value.
They do not establish that the executable exists, is Z3, has the required
capabilities, remains the observed file at launch, or returns sound answers.
They do not prove the behavioral contract, authorize raw `sat`/`unsat` status,
or turn bounded model evidence into a Lean theorem.

The configured runner's behavior is unchanged. Candidate-specific handoff and
query association remain mandatory; only independently replayed input values
can produce a model-relative counterexample receipt. `unsat`, `unknown`, and
status-only `sat` stay neutral. No candidate is pruned, validated
counterexamples are only stably demoted, and any returned structured live
failure restores the original all-`Unassessed` ordering atomically. Exceptions
continue to propagate. Main decodes, activates, and runs this policy only after
the explicit startup option; the decoded contract then remains fixed for that
process while every eligible batch opens a fresh lexical worker.
