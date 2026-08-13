# Contract-only v2 positive-literal modulo

Date: 2026-08-13

## Outcome

Leant's one-shot `:synth --length-contract ABSOLUTE-PATH -- TYPE` entrance now
accepts contract-only versions 1 and 2 under the unchanged format
`leant-finite-list-spine-length-contract`. Version 1 remains the exact grammar
shared with the startup compatibility file. Version 2 adds one expression:

```json
["modulo", positiveLiteral, expression]
```

It is admitted in preconditions, postconditions, and provider-law transfers.
The divisor must be a nonzero Natural literal no wider than 256 bits. The
decoder checks arity, naturalness, the bit bound, and zero before traversing the
operand. Names, provider roles, depth, node and collection limits, and every
other expression/formula tag retain their existing owner and bounds.

The startup configuration remains format version 1. It calls only the v1
contract decoder and therefore rejects `modulo` as an unknown tag. Contract-only
v1 files remain accepted unchanged. A no-modulo contract decodes to the same
`LeanLengthContract` under either contract-only version.

## Authority and lifetime

The file version selects a decoder and is then erased. It is not retained in
`LeanLengthContract`, `LengthAssessmentRequest`, `ParsedGoal`, `ReplState`,
history, snapshots, fingerprints, or presentation. Main's existing flow still:

1. requires an activated startup policy before admitting the explicit path;
2. reads and decodes the contract file once before goal translation;
3. associates that exact lazy contract with the already activated strict
   policy; and
4. threads the request through ordinary, retry, provider, classical,
   verification, ranking, and presentation lanes for that command only.

The next command returns to the startup-fixed contract unless it names another
file. Version 2 adds no process, executable, pin, solver-limit, artifact,
response, evaluation, or replay authority. Provider laws remain explicit
caller assumptions, not inferred or theorem-backed facts.

## QF_LIA lowering

Leant does not normalize modulo or assign it an independent fingerprint.
Djex's checked Length boundary owns normalization, concrete Natural replay, and
query identity. Direct SMT-LIB `mod` is not emitted because it is outside the
declared QF_LIA language. For every normalized surviving occurrence `e mod k`,
Djex allocates deterministic private quotient and remainder witnesses and emits
only linear constraints:

```text
e = k*q + r
q >= 0
r >= 0
r <= k - 1
```

Witness allocation is deterministic preorder, but declarations and constraints
are globally hoisted into the query. Only original source input symbols can
enter `get-value`; quotient and remainder witnesses never become model evidence
or terminal output. Replay computes exact Natural modulo independently from the
returned source inputs.

No-modulo contracts retain their existing canonical bytes and fingerprints.
Contracts containing modulo use Djex's new versioned expression node and
lowering fields, so they cannot collide with the previous language.

## Validation

The focused tests establish:

- the exhaustive new Djex zero-divisor query-error classification;
- exact v1 rejection in both contract-only and startup configuration roots;
- v2 decoding in preconditions, postconditions, and provider transfers;
- v1/v2 equality for a contract without modulo;
- root reordering and format/version/schema precedence;
- wrong arity, negative and mistyped divisors, zero, exact 256-bit admission,
  and 257-bit refusal;
- zero and divisor-bit failures before a malformed operand;
- real acquisition of a v2 one-shot file;
- one activated policy reused with retained v1 and v2 requests after the source
  file is overwritten; and
- provider-transfer and constant modulo through sealing and the fake-Z3
  status/value/assessment path, occurrence sealing, stable demotion, and
  same-receipt presentation.

Djex's own modulo regressions separately pin positional-input replay, nested and
conditional witness lowering, exact QF_LIA bytes, deterministic identities,
and no-modulo golden stability. Leant does not widen its existing handoff
eligibility merely to manufacture a positional-input integration fixture:
premise-backed candidates remain fail-closed at the current exact-origin seam.
