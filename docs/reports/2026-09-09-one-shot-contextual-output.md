# One-shot contextual output and retained specialization evidence

This increment carries the original contextual signature and each selected
candidate's own typed graph through public Haskell one-shot commands. It closes
the documented four-signature, two-engine output matrix below. It also extends
Exference's private certificate association to coexist with lexical dictionary
evidence and gives internal flexible type variables a local Haskell scope.
The complete rank-N/impredicative synthesis goal remains open.

## Public behavior

Both `djex djinn` and `djex exference` accept a custom `--environment DIR`.
The source workspace's normal import/export scope supplies visible types and
providers. Private constructors and class methods do not become ordinary search
providers merely because their declarations were loaded. Source parsing and
Djinn's nominal-name projection use that same checked workspace.

For contextual queries, both the REPL and one-shot frontends share typed
elaboration. Definition output keeps the requested binder scope; standalone
expression output now carries its own annotation and visible type abstractions,
including explicitly quantified outer variables. Unsupported evidence is an
explicit error, not an untyped fallback or a graph borrowed from another result.
Compiler replay uses GHC 9.12.4 with `RankNTypes`, `ImpredicativeTypes`,
`ScopedTypeVariables`, `TypeApplications` and `TypeAbstractions`. The ambiguous
class-method fixture also enables `AllowAmbiguousTypes`; source-specific class
or data extensions still belong to the caller's compilation context.

The public acceptance matrix covers these original signatures:

```haskell
forall a. C a => Token
C a => Token
forall a. C a => (forall b. b -> b) -> Token
C z => forall b. b -> Token
```

Each runs through both Haskell engines, definition and expression output, and
`first/balanced`, `best/balanced`, `all/balanced`, and `all/legacy`: **64 positive
public queries**. Every displayed alternative is compiled and evaluated at the
original signature. The source fixture exports a method and an observer while
hiding the token constructor and class payload method. Its `Int` and `Bool`
dictionaries carry different payloads.

A type-only `forall a. C a => Token` query legitimately admits `method @Int` or
`method @Bool`, as well as forwarding `method @a`. The all-selection oracle now
allows those distinct meanings. Controlled engine tests independently retain
the exact `Int` and `Bool` certificate selections and require their corresponding
rendered expressions. First/best tests retain the forwarding policy. A behavioral
assertion is the appropriate way to require forwarding from every accepted term.

## Evidence and scope repairs

The new private context-aware certificate entrance first uses the shared lexical
context sealer, then performs the existing independent certificate association.
It retains global ownership, complete source schemes, selected arguments,
activated obligations, exact rooted occurrences and complete application chains.
The older context-free entrance still rejects lexical context. An activated
obligation does not become a lexical Given, and the certificate atom still does
not establish instance-discharge identity or independent fingerprint authority.

Nine new association regressions cover valid unused and consumed lexical givens,
legacy rejection, wrong scope, wrong slot, wrong predicate, a different owner,
an incomplete chain and a broken child chain. Exference checks the combined
evidence on actual reconstructed expressions, including both closed dictionary
specializations under an unused root Given.

Legacy all-selection also reaches expressions such as an unused `[]` component,
whose element metavariable has no name in the requested signature. The new tagged
renderer can introduce a local polymorphic helper for such flexible variables.
Unused identity-function arguments carry retained proper term types so GHC can
infer the variable kinds, including higher kinds. The helper presents the same
expression and leaves the candidate graph intact. Generalization cannot capture
variables from the result, locals, globals or lexical dictionaries; rigid
variables remain ineligible. The original generic renderer remains conservative.
Separate compiler replay checks the exact generated helpers at ordinary and
higher kinds; negative tests retain the rigid, captured-global and open-root
boundaries.

## Validation

Strict builds pass with `-Werror`. All **2,371 tests in 16 complete suites pass**:

| Suite | Tests | Seconds |
| --- | --- | --- |
| exference-engine-tests | 93 | 0.27 |
| exference-tests | 515 | 1.41 |
| synthesis-length-tests | 436 | 63.47 |
| djex-tests | 152 | 90.45 |
| djex-api-tests | 38 | 0.03 |
| djex-cli-tests | 124 | 342.65 |
| exference-frontend-api-tests | 4 | 0.0 |
| exference-cli-tests | 25 | 2.24 |
| synthesis-tests | 513 | 0.14 |
| synthesis-certificate-tests | 103 | 0.02 |
| synthesis-term-graph-fingerprint-tests | 11 | 0.0 |
| djinn-source-graph-tests | 59 | 0.29 |
| djinn-source-graph-private-tests | 114 | 0.03 |
| djinn-tests | 133 | 44.27 |
| djinn-cli-tests | 24 | 1.0 |
| djex-parallel-tests | 27 | 0.0 |

The separate public run retains **64 positive queries and 5354 exact displayed alternatives**, all independently compiled and evaluated, plus **four explicit-forall rejection guards** and **eight noninhabitation queries**. Both Haskell signature corpora pass **350/350** with GHC checking at expanded and original resolved signatures. The accepted Exference extended behavior corpus passes **13/13**, one False query and **28 isolated oracle controls** at its original settings. Every recorded source and executable integrity check passes.


The [acceptance receipt](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/one-shot-contextual-output.json)
and [archive](https://github.com/VladimirReshetnikov/Djex/blob/main/test-integration/receipts/one-shot-contextual-output.zip)
retain exact public transcripts, compiler input and observations, complete-suite
inventories and outputs, source snapshots, runtime identities and archive hashes.
Earlier focused failures remain diagnostic history, separate from final acceptance.

## Remaining work

Typed list output, applicable named-`where` one-shot entrances, kinded source
binders and broader provider/dictionary/universe forms remain open. This is
acceptance of the stated public matrix, not an assertion that every conceivable
contextual type or selection stream is supported. Signature inhabitation does not
close the **160-cell Church behavior target**, and native tree acceptance remains
open in all three Lean modes.

Leant retains its tested `bfc3692e` Djex dependency. Its separate deadline repair
has nine completed integration gates, with the final Exference signature corpus
still lacking terminal acceptance. Neither that repair nor native integration of
this canonical Djex increment is certified by the Haskell results in this report.

Archive SHA-256: `bf2cdd8087ad1c2c3f4d9fabf82f7e052b30138fbac70443f1fb0bb7b126a2f7`.
