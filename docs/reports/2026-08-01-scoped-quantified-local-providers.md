# Scoped quantified local providers

> **Follow-up.** The
> [five-binder integration](2026-08-09-five-binder-instantiation.md) raises the
> query-derived and exact-assignment eligibility boundary from four to five.
> The local-provider result below remains the historical starting point.
> The
> [six-binder successor](2026-08-10-six-binder-instantiation.md) raises the
> current shared boundary from five to six without changing this route's
> evidence or closure rules.
>
> A later, separate Djinn family lets non-vacuous query-local hypotheses use
> closed forall-free monotypes already present in the checked goal; see the
> [query-local closed-monotype report](2026-08-09-query-local-closed-monotype-instantiation.md).
> It does not replace the visible vacuous-provider path recorded here.

**Date:** 2026-08-01

**Scope:** Djex-to-Lean synthesis of visible, query-supplied polytype choices
at local vacuous providers

## Outcome

Djinn, Exference, and Leant's combined mode now synthesize and verify the local
provider application in this goal:

```lean
axiom Demo.Token : Type

-- synthesis goal
(∀ x : Type, x → x) → ({a : Type 1} → Demo.Token) → Demo.Token
```

The smallest Djinn candidate is:

```lean
fun _ x => @x (∀ (a0_0 : Type _), a0_0 → a0_0)
```

Exference retains its ranked preference for using both inputs and begins with:

```lean
fun f x => f _ (@x (∀ (a0_0 : Type _), a0_0 → a0_0))
```

Every displayed term has been elaborated by Lean 4.31 against the original
goal.

## Search boundary

Leant intentionally lowers an ordinary opaque atom such as `Demo.Token` to a
query type variable. Exference's root plan opens that variable as an immutable
ambient rigid before it examines the scoped provider. The provider therefore
has the engine shape `forall hidden. <ambient rigid>`.

Djex formerly required the entire provider source to have no free variable of
either flavor. That rejected this safe rigid dependency before expression
checking, even though the same visible application worked for a nominal
`Token` constructor. The query-selected branch now rejects only free flexible
variables. Ambient rigids are fixed by the query plan, survive substitution
unchanged, and are replayed by the independent checker.

The relaxation does not add general impredicative inference:

- every selected type is still a closed, context-free proper type supplied by
  the checked query;
- only fully vacuous leading provider binders use this route;
- unresolved flexible provider dependencies remain rejected;
- the four-binder and 32-combination limits remain; and
- explicit instance-head selection remains a separate monotype-only route.

## Lean rendering boundary

For a named global, retained binder metadata directs a named Lean application.
A local value has no such global binder name, so Leant must render a positional
application with `@`. At this site, a quantified argument written with only
`(a : _)` can leave Lean's universe equation unsolved.

Leant now offers three bounded spellings for quantified binders in a local
visible argument, in order:

1. inferred: `(a : _)`;
2. type-directed: `(a : Type _)`; and
3. proposition-directed: `(a : Prop)`.

They are textual variants of one checked Djex candidate, not separate search
proofs. The existing backend-verification loop keeps the first variant that
elaborates. Each domain receives an independent 12-variant site-and-style
budget so a late selective local application is not displaced by the other
kind hints; the domain-sensitive hard bound is 36, and ordinary duplicate
spellings collapse to the historical smaller group. Named global applications
retain their previous output.

## Validation

The Djex side has direct rigid-versus-flexible provider coverage, raw-search
and independent-checker coverage for nominal and ambient results, and a stable
facade fixture whose `forall r.` definition compiles with GHC 9.12.

The Leant side has a pure all-engine regression that requires the
Type-directed local application inside each standalone verification frontier,
plus a real Lean 4.31 golden transcript for Djinn, Exference, and combined
mode. The complete Leant synthesis suite contains 149 passing tests.
