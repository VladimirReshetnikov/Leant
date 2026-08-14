# Unified checked Length handoff policy

## Outcome

Leant's production Length handoff now converts its two passive contract axes
once into Djex's closed checked interpretation-policy source and then derives
contract and candidate sealing from that one opaque session. The migration
removes the former three-way session branch, two-way contract branch, and
three-way problem branch from `Leant.Synth.Length.Handoff`.

The accepted combinations remain exactly:

| Leant case policy | target roles | Djex policy source |
| --- | --- | --- |
| `cases-rejected` | absent | `LengthLegacyCasesRejected` |
| `cases-rejected` | present | `LengthExplicitTargetRolesCasesRejected` |
| `exact-spine-zero-step-v1` | present | `LengthExplicitTargetRolesExactZeroStepCases` |

`exact-spine-zero-step-v1` without target roles remains invalid and returns
`LengthHandoffExactCasePolicyRequiresTargetRoles`.

## Authority and precedence

The conversion occurs after the exact accepted origin has been checked and
rerendered and after the declared family, constructors, and provider laws have
been resolved through retained translation provenance. Consequently a missing
family or provider still wins over malformed exact-without-roles policy data.
The productive provider-law width check also remains before policy conversion.

Renderer selection deliberately continues to inspect the raw Leant case
policy. A case-rejecting contract keeps the singleton/ordinal-zero rule, while
an exact contract keeps the originating-alternative rule. The policy
conversion therefore does not move renderer demand or turn a Djex sealer
failure into renderer authority.

Once conversion succeeds, production Handoff uses only:

- `sealLengthSessionWithInterpretationPolicy`;
- `sealLengthContractInSession`; and
- `sealLengthTypedCandidateProblemInSession`.

It no longer imports or calls Djex's legacy, role-aware, or exact compatibility
problem wrappers. The checked session is the sole later policy source of truth
and strict association checker. The checked contract may still retain roles as
identity and interpreter inputs, but it cannot independently select the
session's candidate-case authority. Contract resealing and candidate
interpretation therefore cannot accidentally select compatible projections
from different modes.

## Compatibility

This is an authority refactor, not a grammar or semantic expansion. Startup
configuration and contract-only versions 1 through 5 still decode exactly as
before:

- startup/v1/v2 use the legacy case-rejecting policy;
- v3 and v5 `cases-rejected` use explicit roles with rejected cases; and
- v4 and v5 `exact-spine-zero-step-v1` use explicit roles with exact cases.

At this checkpoint Djex kept the historical target-mixedness and case-policy
identity projections, so Leant's legacy and explicit-all-observed checked
problems and canonical queries were byte-identical while genuinely mixed or
exact policies retained distinct identities. The later associated-provider
trust-boundary checkpoint deliberately advances the common Djex Length session
policy versions to 5/6/7. Legacy-versus-explicit-all-observed equivalence still
holds under the current policy, but old containing session, problem, query, and
protocol keys are invalidated. See the
[certificate-carrier handoff report](2026-08-13-length-certificate-carrier-handoff.md).

The subsequent conditional-provider boundary preserves those exact 5/6/7
identities for sessions containing only legacy summaries. A session retaining
any constraint-conditional provider summary instead selects policies 8/9/10
and concrete encodings 4/5/6; an actually ground-discharged associated
candidate uses v3. This does not change the policy-source conversion described
in this report. See the
[live contextual-provider ground-discharge report](2026-08-13-live-contextual-provider-ground-discharge.md).

Existing production regressions also continue to cover the complete matrix:

- legacy startup/v1/v2 preparation and ranking;
- v3 and v5 explicit-role, case-rejecting map preparation;
- v4 and v5 explicit-role exact zero/step preparation;
- v5 quotient lowering under both explicit case policies;
- malformed exact-without-roles precedence behind family/provider failures;
- replayed input/result evidence and ranking outcomes; and
- reuse of retained command-local contracts without policy stickiness.

## Validation

The checkpoint is validated with the strict production and test builds, the
complete 327-test Haskell suite, Cabal package checks, TeX/PDF regeneration,
PDF metadata checks, a source scan confirming that production Handoff contains
only the three unified sealer names, and `git diff --check`.
