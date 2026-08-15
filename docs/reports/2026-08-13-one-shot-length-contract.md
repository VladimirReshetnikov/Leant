# One-shot finite-list-spine Length contracts

Date: 2026-08-13

## Outcome

An activated Length-ranking policy can now assess one `:synth` command under a
separately named passive contract:

```text
:synth --length-contract ABSOLUTE-PATH -- TYPE
```

This is a contract-lifetime change, not a second execution-policy entrance.
The command reuses exactly the policy admitted and activated from the startup
`--length-ranking-config` file. It cannot replace the executable or digest
expectation, solver/resource/deadline controls, artifact policy, response
limits, evaluation limits, or replay bounds. Without that startup authority,
the explicit command is rejected before its path is admitted or read and
before candidate verification.

The no-option command is unchanged. It uses the fixed contract decoded from
the startup compatibility file, or the exact lazy disabled identity when no
policy was activated. Main's default output and solver behavior therefore do
not change.

## Contract-only versions 1 and 2

`Leant.Synth.Length.Contract.File` owns an exact three-field root:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 1,
  "contract": {
    "spine": {
      "family": "List",
      "zero": "List.nil",
      "step": "List.cons"
    },
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["literal", 0]],
    "providerLaws": []
  }
}
```

Unknown, missing, or mistyped root fields fail closed. The nested value goes
through `decodeLeanLengthContractValue`, the same package-private owner used by
the compatibility configuration decoder. Contract tags, names, provider-law
roles and associations, depth/node/count limits, input arity, literals, and
the 256-bit contract-literal ceiling therefore cannot drift between the two
formats.
Version 1 remains byte-for-byte the compatibility contract grammar. Version 2
keeps the same format and exact root, but admits one additional Length
expression in preconditions, postconditions, and provider transfers:

```json
["modulo", 2, ["input", 0]]
```

The divisor is a positive Natural literal no wider than 256 bits. Zero,
negative or mistyped values, wrong arity, and maximum-plus-one bits fail closed;
divisor validation precedes operand traversal. The startup compatibility file
remains version 1 and rejects the tag, and contract-only version-1 documents
continue to decode exactly as before.

Leant retains the passive expression rather than normalizing it. Djex owns
normalization, evaluation, replay, and query identity. A surviving occurrence
is not rendered with SMT-LIB `mod` (which is outside QF_LIA): Djex introduces
private deterministic quotient and remainder witnesses and asserts
`e = k*q + r`, `q >= 0`, `r >= 0`, and `r <= k-1`. Those witnesses are never
requested by `get-value` or exposed by replay/presentation. Provider transfers
remain caller-supplied assumptions, regardless of whether they use modulo.

The contract-only root deliberately contains no execution admission,
execution, or evaluation object.

Both formats retain the strict bounded JSON ceiling of 262,144 bytes. The
contract-only facade maps malformed JSON or contract syntax into closed
contract-file diagnostics. Source bytes, paths, provider names, syntax tags,
and errno text do not enter those diagnostics.

## One acquisition owner

`Leant.Synth.Length.File.Acquire` now owns the mechanics shared by startup and
one-shot files:

- productive 4,096-character absolute-path admission before timeout demand;
- a positive timeout no greater than 60,000 milliseconds;
- POSIX final-component no-follow, nonblocking, no-controlling-terminal, and
  close-on-exec descriptor acquisition;
- regular-file inspection before the first read;
- maximum-plus-one byte accounting, bounded interruption, masked handoff, and
  cleanup observation; and
- closed generic phases which the two facades map exhaustively into their own
  vocabulary.

The one-shot command uses a fixed 5,000-millisecond interruption budget. The
timeout remains a same-process interruption bound rather than a hard kernel IO
deadline. Ancestor symlinks and in-place modification of an open regular file
are not excluded, and uninterruptible filesystem work or close can outlive the
interval. Windows continues to fail closed until it has an equivalent native
handle boundary.

`Configuration.File.Acquire` preserves the established startup API and error
types over that leaf. `Contract.File.Acquire` exposes only contract-file
vocabulary. Neither facade discovers a path or launches Z3.

## Command-local association and lifetime

`Leant.Synth.Length.Command` recognizes only the exact
`--length-contract` option at the beginning of `:synth` input. A standalone
`--` delimiter is mandatory. Everything after it remains opaque goal text;
the trimmed path before it may contain spaces, so the delimiter spelling is
reserved inside that path. Missing paths and delimiters are errors rather than
silently becoming Lean goals, while a longer token such as
`--length-contractual` remains ordinary goal text.

`Leant.Synth.Length.Integration` provides two opaque steps. First,
`authorizeExplicitLengthAssessmentRequest` projects only an activated policy
permission; disabled mode returns a closed refusal without accepting a path or
contract. After bounded decoding, `explicitLengthAssessmentRequest` associates
that exact permission with one lazy contract. The resulting
`LengthAssessmentRequest` has only two authority shapes: disabled, or one
strict policy beside one lazy contract. It does not retain whether an enabled
contract came from the startup compatibility document or the one-shot file.

Main constructs the request once before translating the goal. The same value
is passed through ordinary synthesis, universe retry, provider widening,
classical fallback, and every verification/presentation batch for that
command. It is not placed in `ReplState`, `ParsedGoal`, command history,
snapshots, environment companions, or a cache. The source file is never
reopened by those lanes. A later command therefore returns to the fixed startup
contract unless it explicitly loads another one.

Both enabled lifetimes enter the same policy-plus-contract post-verification
adapter. Candidate admission still observes maximum plus one before the lazy
contract or candidate elements are forced. The exact occurrence permutation,
query association, replay gate, atomic fallback, and same-ranked-receipt
presentation boundary are unchanged. A one-shot contract can alter neutral
ordering evidence for that command, but it grants neither proof nor pruning
authority.

## Validation

The focused regressions cover:

- exact option parsing, mandatory delimiter, missing path, and the
  longer-token non-option case;
- contract-root format/version/schema failures, reordered version-2 roots, and
  redacted nested errors;
- exact version-1 compatibility, version-1 rejection of modulo, version-2
  no-modulo parity, and modulo decoding in preconditions, postconditions, and
  provider transfers;
- positive-divisor arity/type/zero checks, exact 256-bit admission, 257-bit
  refusal, and divisor-before-operand failure precedence;
- exact 256-provider-law admission and maximum-plus-one refusal;
- relative-path-before-timeout admission, real regular-file decoding,
  missing/malformed files, the byte cap, sanitized diagnostics, and cleanup;
- disabled authorization without file IO or batch demand;
- one activated policy used with version-1 and version-2 contracts, including
  provider-transfer and constant modulo through sealing and fake-Z3 assessment
  with different sealed candidate orders;
- source mutation after each one-time load, repeated use of the retained first
  request, and no contract stickiness between request values; and
- maximum-plus-one candidate rejection before a poisoned contract or candidate
  tail can be inspected.

The maintained default, startup v1 activation, sealed ordering, fallback,
presentation, and configuration-file suites continue to run beside these
checks. The modulo tandem advances the Djex gitlink, but changes no existing
fingerprint bytes, wire protocol, Main state snapshot, or default command
behavior; only contracts which actually contain modulo use Djex's versioned
node/lowering identity additions.

## Deliberate limits

This is still only `finite-list-spine-length/v1`. The command does not infer a
contract from `TYPE`, parse behavioral assertions from Lean syntax, prove
provider laws, attest Z3, cache a worker, or establish source-level behavioral
equivalence. Future domains require their own checked semantics and evidence
replay rather than an extension of this command parser into a generic solver
interface.

The additive canonical-`Prod` checkpoint follows that rule. Its
`LeanLengthSpinePairContract` is a library-level passive source and is not
decoded by startup configuration versions 1--3 or contract-only versions
1--5. Its product query and replay boundary is offline only: no product option,
JSON tag, live worker request, ranking policy, or presentation grammar is
introduced here. See the
[canonical `Prod` Length handoff report](2026-08-14-canonical-prod-length-handoff.md).

Later additive contract-only versions preserve this command-local acquisition
and lifetime owner. Version 3 adds explicit target roles and version 4 adds the
single explicit exact zero/step case policy; neither can replace execution
authority or become sticky state. See the
[v3 role report](2026-08-13-contract-only-v3-target-roles.md) and
[v4 exact-case report](2026-08-13-contract-only-v4-exact-spine-cases.md).
