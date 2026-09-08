-- Exact debug candidates from native-djinn-v2; no synthesis occurs here.
-- Predicate text is retained verbatim beneath its original lexical name.
set_option autoImplicit false

-- append group 11, variant 0; original transcript line 65
def NativeWitness.append_anonymous : ({α : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → List α → List α → List α) :=
fun f x y => f _ (.cons) y x
theorem NativeWitness.append_anonymous_checked : (
let recursor_djinn_native_append : ({α : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → List α → List α → List α) := NativeWitness.append_anonymous;
(recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [] [] = ([] : List Nat)) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [] [11, 29] = [11, 29]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [11, 29] [] = [11, 29]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [11, 29] [37, 41, 53] = [11, 29, 37, 41, 53]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Bool ρ) [true, false] [true] = [true, false, true])
) := by decide

-- append group 11, variant 1; original transcript line 66
def NativeWitness.append_qualified : ({α : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → List α → List α → List α) :=
fun f x y => f _ List.cons y x
theorem NativeWitness.append_qualified_checked : (
let recursor_djinn_native_append : ({α : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → List α → List α → List α) := NativeWitness.append_qualified;
(recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [] [] = ([] : List Nat)) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [] [11, 29] = [11, 29]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [11, 29] [] = [11, 29]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [11, 29] [37, 41, 53] = [11, 29, 37, 41, 53]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Bool ρ) [true, false] [true] = [true, false, true])
) := by decide

-- length group 2, variant 0; original transcript line 42
def NativeWitness.length_fold : ({α τ : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → τ → (τ → τ) → List α → τ) :=
fun f x g y => f _ (fun _ => g) x y
theorem NativeWitness.length_fold_checked : (
let recursor_djinn_native_length : ({α τ : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → τ → (τ → τ) → List α → τ) := NativeWitness.length_fold;
(recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [] = 0) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [11] = 1) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [11, 29] = 2) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [11, 29, 37, 41, 53] = 5) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Bool ρ) 0 Nat.succ [true, false, true] = 3) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) true Bool.not [11, 29] = true) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) true Bool.not [11, 29, 37] = false)
) := by decide

-- append group 2, variant 0; original transcript line 43
def NativeWitness.append_projection_control : ({α : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → List α → List α → List α) :=
fun _ _ x => x
theorem NativeWitness.append_projection_control_checked : ¬ (
let recursor_djinn_native_append : ({α : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → List α → List α → List α) := NativeWitness.append_projection_control;
(recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [] [] = ([] : List Nat)) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [] [11, 29] = [11, 29]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [11, 29] [] = [11, 29]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Nat ρ) [11, 29] [37, 41, 53] = [11, 29, 37, 41, 53]) ∧ (recursor_djinn_native_append (fun ρ => @List.foldr Bool ρ) [true, false] [true] = [true, false, true])
) := by decide

-- length group 1, variant 0; original transcript line 41
def NativeWitness.length_constant_control : ({α τ : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → τ → (τ → τ) → List α → τ) :=
fun _ x _ _ => x
theorem NativeWitness.length_constant_control_checked : ¬ (
let recursor_djinn_native_length : ({α τ : Type} → (∀ ρ : Type, (α → ρ → ρ) → ρ → List α → ρ) → τ → (τ → τ) → List α → τ) := NativeWitness.length_constant_control;
(recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [] = 0) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [11] = 1) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [11, 29] = 2) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) 0 Nat.succ [11, 29, 37, 41, 53] = 5) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Bool ρ) 0 Nat.succ [true, false, true] = 3) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) true Bool.not [11, 29] = true) ∧ (recursor_djinn_native_length (fun ρ => @List.foldr Nat ρ) true Bool.not [11, 29, 37] = false)
) := by decide

#print axioms List.foldr
#print axioms NativeWitness.append_anonymous
#print axioms NativeWitness.append_anonymous_checked
#print axioms NativeWitness.append_qualified
#print axioms NativeWitness.append_qualified_checked
#print axioms NativeWitness.length_fold
#print axioms NativeWitness.length_fold_checked
#print axioms NativeWitness.append_projection_control
#print axioms NativeWitness.append_projection_control_checked
#print axioms NativeWitness.length_constant_control
#print axioms NativeWitness.length_constant_control_checked
