# Implicit Haskell signatures retain type scope and dictionary choices

Djex now closes implicitly quantified source signatures before constructing
either engine's typed candidate graph. Contextual REPL output and the behavioral
worker use GHC visible type patterns to bind those variables at the definition
site. This extends the earlier explicit-forall contextual output to the
implicit-signature cases below, without rewriting the user's requested type.

## Why both graph closure and binding scope are needed

For a constraint-only method, a signature such as `C a => Token` leaves `a`
absent from the result. A bare method application can silently lose the caller's
dictionary choice. Adding `forall` only inside a renderer also leaves the source
graph open or inconsistent with the requested scheme.

The source parser now quantifies free root variables in their written
first-occurrence order. An explicit outer `forall` obeys the forall-or-nothing
rule and rejects remaining unbound variables. Synonym expansion still occurs
at its existing query-elaboration boundary, preserving its diagnostic contract.

Definition output scopes implicit variables with visible type patterns. For
example, the relevant shape for a constraint-only provider is:

```haskell
selected :: C a => Token
selected @a = method @a
```

This syntax requires `TypeAbstractions` on the supported GHC 9.12.4 toolchain,
along with the existing contextual/rank-N extensions used by the signature.
Expression output supplies its own explicitly polymorphic annotation and type
abstraction. The standalone expression is applied directly in acceptance tests;
assigning it as an ordinary RHS under an ambiguous implicit signature still
requires appropriate binding-site scope.

The behavioral worker uses the same visible patterns for its fresh private
binding and named alias, forwarding the exact type arguments between them.
Hint 0.9.0.9 lacks a `TypeAbstractions` enumeration constructor, so the worker
passes the constant `-XTypeAbstractions` flag through Hint's interpreter-argument
API. Its package-qualified runtime Boolean boundary, capture avoidance,
timeouts and worker-retirement controls remain in place.

## Synonym identity regression

The first full run passed 360/361 tests. The failing test expected an empty
source-name map after expanding `Phantom erased`, where:

```haskell
type Inner = forall b. b -> b
type Phantom a = Inner
```

Direct GHC replay establishes that the implicit signature retains a vacuous
outer binder: `f @Bool @Int 37` is valid and evaluates to `37`. Keeping that
binder's source name is correct. The strengthened integration test checks:

- Both implicit and explicit outer binders retain only their own spelling.
- The synonym-introduced identity binder has no borrowed source spelling,
  checked against the selected candidate's own graph type.
- A binder inside `Phantom (forall erased. erased -> erased)` is actually
  erased, so its hint map is empty. GHC replay of this synonym form uses
  `LiberalTypeSynonyms`.
- All three synthesized definitions compile at their original signatures and
  evaluate correctly with visible type applications.

No production hint-ownership guard was removed. The previously published
[failed receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/implicit-root-retriage.json)
and archive remain historical evidence; the new test distinguishes a surviving
vacuous binder from a genuinely erased binder.

## Public acceptance and complete regressions

Strict builds pass. All **361 tests across six complete affected suites pass**:

| Suite | Tests | Seconds |
| --- | --- | --- |
| djex-tests | 152 | 176.41 |
| djex-api-tests | 38 | 0.04 |
| djex-parallel-tests | 27 | 0.0 |
| exference-frontend-api-tests | 4 | 0.0 |
| exference-cli-tests | 25 | 3.26 |
| djex-cli-tests | 115 | 309.22 |

The full Church signature harness also passes **350/350 per Haskell engine**,
with GHC compilation at the expanded and original resolved signatures,
the existing two-second query timeout and 10,000-step budget. All recorded
source and executable integrity checks pass.


The new CLI fixture covers these five signatures in both Haskell engines:

```haskell
C a => Token
((C a => Token))
C z => a -> Token
C a => (forall b. b -> b) -> Token
C a => forall b. b -> Token
```

Ordinary and named-`where` queries each exercise expression and definition
output, yielding **40 positive public queries with exact GHC replay**. The
fixture also includes **20 actual False controls** and **four invalid explicit
forall guards**. Every positive replay distinguishes Int payload 37 from Bool
payload 91. Limits remain first selection, window/candidate limit 4, 20,000
Djinn choices and 256 Exference steps. The earlier explicit-forall
first/best/all and Both-mode fixtures remain in the full CLI regression suite.

The [acceptance receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/implicit-root-scope.json)
and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/implicit-root-scope.zip)
retain source snapshots, compiler probes, raw results, inventories, exact runtime
identities and unchanged-input checks. The whole-signature corpus is
inhabitation evidence; it does not establish Church behavioral completeness.

## Remaining scope

This closes the documented implicit-root contextual REPL increment within
priority 3. One-shot contextual commands, typed list output, broader binder
forms including repeated source spellings, derived methods, mixed Lean
inventories and richer dictionary evidence retain their separate requirements.
The complete implicit-signature first/best/all/Both matrix is also broader than
the new first-selection fixture. The helper does not invent scope when it
cannot represent the source binders safely.

Leant keeps its tested Djex dependency pending native integration of this
frontend revision. The native tree diagnostic is next, followed by the remaining
public frontend and full Church behavioral work. All priorities 1–4, including
all 13 extended and 19 supplied-default operations across five modes, remain
in force.

Archive SHA-256: `4849f2f4fe4945ac621a0271e0813a08380a0a9db3ef9666ef7b06f226ccd6ad`.
