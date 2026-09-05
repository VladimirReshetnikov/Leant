/-
The positional renderer must expose an implicit binder reached after a term
argument at the original known head (`@factory seed ...`). Lean does not accept
`@(factory seed) ...`. These constructive witnesses also pin the behavior of
explicit `_` instance arguments and differing annotation/expected visibility.
-/
set_option linter.unusedVariables false

namespace ChurchMixedSpine

class Marker (α : Type 1) where
  marker : Unit

instance {α : Type 1} : Marker α := ⟨()⟩

def implicitSource : ∀ (Seed X : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ {a : Type 1}, a → Seed → ∀ {b : Type 1}, b → G a b) →
    G (∀ c : Type, X → c → c) (∀ d : Type, d → d) :=
  fun Seed X G seed factory =>
    @factory seed (∀ c : Type, X → c → c) (fun _ _ value => value)
      seed _ (fun _ value => value)

def instanceSlots : ∀ (Seed X : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ {a : Type 1}, ∀ [Marker a], a → Seed →
      ∀ {b : Type 1}, ∀ [Marker b], b → G a b) →
    G (∀ c : Type, X → c → c) (∀ d : Type, d → d) :=
  fun Seed X G seed factory =>
    @factory seed (∀ c : Type, X → c → c) _ (fun _ _ value => value)
      seed _ _ (fun _ value => value)

def implicitTarget : ∀ (Seed X : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ {a : Type 1}, a → Seed → ∀ {b : Type 1}, b → G a b) →
    G (∀ {c : Type}, X → c → c) (∀ {d : Type}, d → d) :=
  fun Seed X G seed factory =>
    @factory seed (∀ c : Type, X → c → c) (fun _ _ value => value)
      seed _ (fun value => value)

#print axioms implicitSource
#print axioms instanceSlots
#print axioms implicitTarget

def closedImplicitTarget : ∀ (Seed : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ a : Type 1, a → Seed → ∀ b : Type 1, b → G a b) →
    G (∀ {c : Type}, c → c) (∀ d : Type, d → d) :=
  fun Seed G seed factory =>
    let first := factory seed (∀ c : Type, c → c) (fun _ value => value)
    let second := first seed
    second _ (fun _ value => value)

def exactFactory {a : Type 1} (_ : a) (_ : Unit) {b : Type 1} (_ : b) : Unit := ()

def exactLeadingChoice : Unit → Unit :=
  fun seed => @exactFactory (∀ {c : Type}, c → c) (fun value => value)
    seed (∀ d : Type, d → d) (fun _ value => value)

#print axioms closedImplicitTarget
#print axioms exactLeadingChoice

def inferredClosedChoice : ∀ (Seed : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ a : Type 1, a → Seed → ∀ b : Type 1, b → G a b) →
    G (∀ {c : Type}, c → c) (∀ d : Type, d → d) :=
  fun _ _ seed factory => factory seed _ (fun {_} value => value)
    seed _ (fun _ value => value)

def inferredOpenChoice : ∀ (Seed X : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ {a : Type 1}, a → Seed → ∀ {b : Type 1}, b → G a b) →
    G (∀ {c : Type}, X → c → c) (∀ {d : Type}, d → d) :=
  fun _ _ _ seed factory => factory seed (fun {_} _ value => value)
    seed (fun value => value)

def inferredNestedChoice : ∀ (Seed : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ {a : Type 1}, a → Seed → ∀ {b : Type 1}, b → G a b) →
    G (∀ {c : Type}, c → ∀ {d : Type}, d → c) (∀ e : Type, e → e) :=
  fun _ _ seed factory => factory seed (fun {_} value {_} _ => value)
    seed (fun _ value => value)

#print axioms inferredClosedChoice
#print axioms inferredOpenChoice
#print axioms inferredNestedChoice

end ChurchMixedSpine
