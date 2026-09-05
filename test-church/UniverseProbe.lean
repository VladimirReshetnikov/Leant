set_option linter.unusedVariables false

-- The acceptance corpus expands aliases and infers each quantifier's universe
-- independently. Nested Church encodings therefore do not pretend Type is
-- impredicative: Lean solves the genuine universe constraints on every goal.
example : (∀ (a : Type _) (b : Type _),
    (∀ r : Type _, (a → b → r) → r) → a) :=
  fun a b p => p a (fun x _ => x)

example : (∀ (a : Type _),
    (∀ r : Type _, (a → r → r) → r → r) →
      (∀ r : Type _, (a → r → r) → r → r)) :=
  fun a xs r c z => xs r c z

example : (∀ F : Type _ → Type _,
    (∀ a : Type _, F a) → F (∀ b : Type _, b → b)) :=
  fun F supply => supply _

example : (∀ R : Type,
    (((∀ {A : Type}, A → A) → (∀ {B : Type}, B → B)) → R) → R) :=
  fun _ f => f (fun x => x)

example : (∀ R : Type,
    (((∀ {A : Type}, A → A) → (∀ {B : Type}, B → B)) → R) → R) :=
  fun _ f => f (fun x => @x)

example : (∀ R : Type,
    (((∀ {A : Type}, A → A) → (∀ {B : Type}, B → B)) → R) → R) :=
  fun _ f => f (fun _ => fun x => x)

example : (∀ R : Type,
    (((∀ {A : Type}, A → A) → (∀ {B : Type}, B → B)) → R) → R) :=
  fun _ f => f (fun _ {_} x => x)

example : (∀ F : Type 1 → Type 1,
    (Unit → ∀ a : Type 1, a → F a) → F (∀ b : Type, b → b)) :=
  fun _ f => f () _ (fun _ x => x)

example : (∀ F : Type 1 → Type 1,
    (Unit → ∀ {a : Type 1}, a → F a) → F (∀ {b : Type}, b → b)) :=
  fun _ f => f () (fun x => x)

example : (∀ (F : Type 1 → Type 1) (A : Type),
    (∀ a : Type 1, a → F a) → F (∀ B : Type, A → B → B)) :=
  fun _ _ f => f _ (fun _ _ x => x)

-- A directly constructed match scrutinee has no expected family. Explicit
-- names support both the data and proposition interpretations of sum syntax.
example : ∀ (A : Type _) (B : Type _), (A → B) → B → B :=
  fun _ _ f x => match Sum.inr x with | .inl a => f a | .inr b => b

example : ∀ (A B : Prop), (A → B) → B → B :=
  fun _ _ f x => match Or.inr x with | .inl a => f a | .inr b => b

-- These two terms have rank seven: each continuation wrapper places the
-- previous polymorphic type below two additional arrow domains. Wide binder
-- spines alone do not demonstrate a high rank.
example : (∀ A : Type, ((∀ B : Type, ((∀ C : Type,
    ((∀ D : Type, D → D) → C) → C) → B) → B) → A) → A) :=
  fun _ f => f (fun _ g => g (fun _ h => h (fun _ x => x)))

example : (∀ {A : Type}, ((∀ {B : Type}, ((∀ {C : Type},
    ((∀ {D : Type}, D → D) → C) → C) → B) → B) → A) → A) :=
  fun f => f (fun g => g (fun h => h (fun x => x)))

example : (∀ (F : Type 1 → Type 1) (G H K : Type → Type),
    (∀ a : Type 1, a → F a) → (∀ a : Type, G a → H a) →
    (∀ a : Type, H a → K a) → F (∀ a : Type, G a → K a)) :=
  fun _ _ _ _ p u v => p _ (fun a x => v a (u a x))

example : (∀ F : Type 1 → Type 1, (∀ a : Type 1, a → F a) →
    F (∀ b : Type, b → F (∀ c : Type, c → c))) :=
  fun _ p => p _ (fun _ _ => p _ (fun _ x => x))

example : (∀ F : Type 1 → Type 1, (∀ a : Type 1, a → F a) →
    F (∀ b : Type, b → F (∀ c : Type, b → c → b))) :=
  fun _ p => p _ (fun _ _ => p _ (fun _ x _ => x))

-- The result of the pair elimination below is determined by consume. The
-- inner let preserves choose's whole polymorphic result until its use.
example : (∀ A B R : Type, (A → ∀ D : Type, D → D → D) →
    (∀ C : Type, (A → B → C) → C) → (B → R) → R) :=
  fun _ _ _ f g h => h (g _ (fun x y => let f1 := f x; f1 _ y y))

-- A source may introduce a new forall after each ordinary application.
example : (∀ (Seed : Type) (G : Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ a : Type 1, a → Seed → ∀ b : Type 1, b → G a b) →
    G (∀ a : Type, a → a) (∀ b : Type, b → b)) :=
  fun _ _ seed p => p seed _ (fun _ x => x) seed _ (fun _ x => x)

example : (∀ (Seed : Type) (G : Type 1 → Type 1 → Type 1 → Type 1), Seed →
    (Seed → ∀ a b : Type 1, a → b → Seed → ∀ c : Type 1, c → G a b c) →
    G (∀ a : Type, a → a) (∀ b : Type, b → b → b) (∀ c : Type, c → c)) :=
  fun _ _ seed p =>
    p seed _ _ (fun _ x => x) (fun _ x _ => x) seed _ (fun _ x => x)
