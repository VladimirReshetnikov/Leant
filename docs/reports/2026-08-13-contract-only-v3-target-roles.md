# Contract-only v3 explicit target roles

Date: 2026-08-13

## Outcome

Leant's one-shot
`:synth --length-contract ABSOLUTE-PATH -- TYPE` entrance now accepts
contract-only version 3 under the unchanged format
`leant-finite-list-spine-length-contract`. The root remains the exact
three-field object `format`, `version`, and `contract`. Version 3 retains the
complete version-2 expression grammar, including positive-literal Natural
modulo, and additionally requires one exact source-ordered role for every
physical target argument.

A role-aware map contract has this exact shape:

```json
{
  "format": "leant-finite-list-spine-length-contract",
  "version": 3,
  "contract": {
    "spine": {
      "family": "List",
      "zero": "List.nil",
      "step": "List.cons"
    },
    "targetArgumentRoles": [
      "unobserved-target",
      "observed-spine"
    ],
    "precondition": ["truth", true],
    "postcondition": ["equal", ["result"], ["literal", 0]],
    "providerLaws": [
      {
        "name": "Demo.mapList",
        "argumentRoles": ["unobserved", "spine"],
        "transfer": ["argument", 1]
      }
    ]
  }
}
```

`targetArgumentRoles` must be an array with at most eight entries. Each entry
must be exactly `"observed-spine"` or `"unobserved-target"`; unknown values,
wrong JSON types, and maximum-plus-one entries fail closed without retaining
the rejected value. The later checked contract boundary requires the array
length to equal the complete physical function-argument spine after leading
quantifiers. File decoding cannot and does not guess that arity from the
separately supplied Lean goal.

## Version isolation

The change is additive at the contract-only root:

- contract-only version 1 retains the exact startup-compatible grammar;
- contract-only version 2 retains that grammar plus modulo;
- contract-only version 3 retains modulo and requires
  `targetArgumentRoles`; and
- the startup live-ranking configuration remains format version 1 and still
  invokes only the version-1 nested contract decoder.

Consequently, contract-only versions 1 and 2 and the startup configuration
reject `targetArgumentRoles` as an unexpected contract field. Version 3
rejects its absence. Version 1 and startup continue to reject `modulo`, while
versions 2 and 3 admit it in preconditions, postconditions, and provider-law
transfers with the existing positive, nonzero, 256-bit divisor checks. No
version gains execution, executable, pin, artifact, response, evaluation, or
replay policy fields.

The file version selects the decoder and is then erased. The decoded
`LeanLengthContract` retains `Nothing` for the unchanged version-1/version-2
legacy policy and `Just roles` for version 3. This is an explicit source
assertion, not an inference marker.

## One explicit role authority

Leant does not infer target roles from the goal type, the configured spine
name, a provider name or scheme, the provider-law roles, a synthesized term,
or Lean elaboration. `Leant.Synth.Length.Handoff` uses the decoded choice at
all three Djex boundaries:

- `Nothing` selects the established all-observed session, contract, and typed
  candidate sealers; and
- `Just roles` sends that same vector through the role-aware session,
  contract, and typed-candidate sealers.

The checked contract is the retained owner of the complete ordered vector.
The role-aware session retains only the compatible legacy-or-mixed semantic
policy discriminator, and candidate sealing revalidates the contract and
requires the session policy to agree. The result must still be the configured
modeled list spine in either mode.

Only `"observed-spine"` target positions must themselves have the configured
spine type. These positions receive compact `LengthInput` numbers in their
source order. For example, the physical target spine

```text
(a -> b) -> List a -> List b
```

with roles

```text
[unobserved-target, observed-spine]
```

has two physical arguments but exactly one Length input, `LengthInput 0`.
There is no input symbol or replay assignment for physical position 0.

Provider-law numbering remains deliberately different. Its `argumentRoles`
array aligns with every physical provider argument after leading quantifiers,
and `LengthProviderArgument n` addresses that physical position. It is not
compacted by provider role. Thus the map law above uses provider roles
`[unobserved, spine]` and transfer `["argument", 1]`: physical provider
argument 1 supplies the length which becomes compact target `LengthInput 0`.
Changing the transfer to argument 0 would reference the explicitly
unobserved provider position and fail provider-law sealing rather than being
silently renumbered.

## Opaque means non-inspectable, not semantic evidence

For an `unobserved-target` position, Djex's checked candidate interpreter
supplies a private opaque token carrying only the physical position. The token
is not a Natural length, a fabricated inhabitant, a bottom approximation, or
an arbitrary semantic value. A non-demanding checked term may ignore it,
forward it to a provider argument explicitly sealed as `unobserved`, or carry
it through another interpreter path which does not inspect that payload.

Trying to use the token as a callable value, observe it as a list spine, or
destructure it as a tuple rejects candidate preparation with an explicit
opaque-demand error. It cannot enter Length arithmetic, a contract formula, a
branch condition, equality, SMT-LIB, `get-value`, or counterexample replay.

The role makes no claim that the source argument type is inhabited. It makes
no claim that a Lean implementation or provider does or does not evaluate the
argument, and no claim about purity, totality, parametricity, strictness, or
effects. In particular, forwarding the opaque token is only a fact about this
bounded model-relative Length interpretation under an explicitly assumed
provider law. It is not a theorem about source evaluation or behavior.

## Command-local lifetime

Version 3 preserves the one-shot lifetime exactly. Main first requires an
already activated startup policy, then admits, reads, and decodes the named
contract file once before goal translation. The resulting request is threaded
through the ordinary, universe-retry, provider, classical, verification,
ranking, and presentation lanes for that command.

Neither the file version nor the role vector is stored in `ParsedGoal`,
`ReplState`, history, snapshots, environment companions, or a cache. The file
is not reopened by later lanes. Reusing the retained request after the source
file is overwritten continues to use the first decoded value, while a later
command without `--length-contract` returns to the fixed startup version-1
compatibility contract. Version 3 therefore adds no policy or contract
stickiness.

## Focused typed map path

The Leant regression constructs a closed generic target and provider scheme
for

```text
(a -> b) -> List a -> List b
```

using exact structural `FParamRec` occurrences for every `List` application.
That gives translation one native `List` family binding with the exact
`List.nil` and `List.cons` provenance required by the Length handoff. The
provider is the exact `Demo.mapList` binding, its scheme is alpha-equivalent to
the target, and the selected Exference candidate retains a graph-backed typed
origin rather than a legacy rendering fallback.

This fixture deliberately uses the package-private
`synthesizeWithProvidersSkippingDetailedWithMultiConstructorPatterns` seam
with multi-constructor pattern generation disabled. The focused setting keeps
a simple checked provider graph inside the bounded fixture; it does not alter
Main's search policy. Every existing production entrance continues through
`synthesizeWithProvidersSkippingDetailed` or `synthesizeTunedDetailed`, whose
shared wrapper passes `True`, so production Exference search retains its
established multi-constructor-pattern behavior. The sidecar also retains the
exact tuned request which produced it; the handoff does not pretend it came
from a default-policy run.

The focused pure and fake-solver path checks that:

- the exact verified typed origin survives callback verification and
  candidate-specific rerendering;
- the structural `List` family and `Demo.mapList` provider are resolved from
  retained provenance;
- target roles `[unobserved-target, observed-spine]` and provider roles
  `[unobserved, spine]` produce result `LengthInput 0` and record exactly one
  used provider;
- the sealed query requests only `djex_length_input_0`;
- omitting roles preserves the legacy higher-order-input rejection, a short
  vector produces exact arity mismatch, and swapping the roles rejects the
  higher-order argument as a requested spine;
- one loaded v3 request remains usable after its source file is corrupted and
  repeated assessment does not make it process-global; and
- a satisfiable fake model is independently replayed as one compact input and
  a result, while presentation calls that vector the observed input spine
  lengths, reports only the count of assumed provider laws, and does not expose
  the provider name. The extra role qualification increases the hard sanitized
  note ceiling from 360 to 384 characters; default and no-evidence output stay
  unchanged.

The tuned seam makes this a deterministic boundary regression. It does not
claim that production search must discover or rank this particular provider
term within every bounded candidate window.

## Djex gitlink and identity schemas

Leant advances the vendored Djex gitlink from modulo revision `8143ecb` to
role-aware revision `ee60257` (`Admit role-aware Length target arguments`).
That Djex revision adds the closed public target-role vocabulary and the
role-aware session, contract, and typed-candidate sealing entrances used by
the handoff.

Identity changes are conditional on a mixed vector containing at least one
unobserved target role:

- mixed contracts use the existing contract role at builder version 3 and
  bind the complete ordered role vector plus compact observed count;
- mixed sessions use the existing solver-neutral encoding role at builder
  version 3 and bind the opaque-forward-only interpreter policy; and
- mixed concrete encodings use the existing concrete-encoding role at builder
  version 2 and bind the role-aware interpreter policy.

Legacy calls and explicit all-observed role-aware calls retain the historical
contract version 2, session version 2, and concrete-encoding version 1
canonical bytes. The generic behavioral-problem schema, candidate identity,
QF_LIA query schema, wire commands, response grammar, and evidence-replay
schema are unchanged. Version 3 modulo expressions retain the separate
versioned modulo expression identity introduced by the preceding Djex
revision; role awareness neither removes nor reinterprets it.

## Deliberate limits

Contract-only v3 is still the `finite-list-spine-length/v1` model-relative
ranking domain. It does not infer a contract, prove a provider law, establish
source-level behavioral equivalence, grant proof or pruning authority, or turn
raw solver status into evidence. The explicit roles only make a previously
unsupported mixed physical target spine available to the same checked,
bounded, replayed counterexample pipeline.
