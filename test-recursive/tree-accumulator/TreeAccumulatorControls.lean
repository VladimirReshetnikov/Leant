set_option autoImplicit false
namespace TreeAccumulatorFixture
set_option genSizeOf false in inductive Tree (α : Type) where | leaf : α → Tree α | branch : Tree α → Tree α → Tree α
end TreeAccumulatorFixture
def TreeAccumulatorFixture.foldTree {α ρ : Type} (leaf : α → ρ) (branch : ρ → ρ → ρ) : TreeAccumulatorFixture.Tree α → ρ | .leaf x => leaf x | .branch l r => branch (TreeAccumulatorFixture.foldTree leaf branch l) (TreeAccumulatorFixture.foldTree leaf branch r)
namespace TreeAccumulatorControls
def observations (f : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ) : Prop :=
(f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.leaf 2) = 72) ∧ (f (fun (state value : Nat) => 10 * state + value) 0 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.leaf 2)) = 12) ∧ (f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.leaf 2)) = 712) ∧ (f (fun (state value : Nat) => 10 * state + value) 37 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.leaf 2)) = 3712) ∧ (f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.leaf 2)) (TreeAccumulatorFixture.Tree.leaf 3)) = 7123) ∧ (f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 2) (TreeAccumulatorFixture.Tree.leaf 3))) = 7123) ∧ (f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.leaf 2)) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 3) (TreeAccumulatorFixture.Tree.leaf 4))) = 71234) ∧ (f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 2) (TreeAccumulatorFixture.Tree.leaf 3)) (TreeAccumulatorFixture.Tree.leaf 4))) = 71234) ∧ (f (fun (state value : Nat) => 10 * state + value) 7 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 2) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 3) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 4) (TreeAccumulatorFixture.Tree.leaf 5))))) = 712345) ∧ (f (fun (state value : Nat) => state * state + value) 2 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 2) (TreeAccumulatorFixture.Tree.leaf 3))) = 732) ∧ (f (fun (state value : Nat) => state * state + value) 3 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.leaf 2)) (TreeAccumulatorFixture.Tree.leaf 3)) = 10407) ∧ (f (fun (state : Nat) (value : Bool) => 2 * state + (if value then 1 else 0)) 3 (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf true) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf false) (TreeAccumulatorFixture.Tree.leaf false))) = 28) ∧ (f (fun (state : List Nat) (value : Nat) => state ++ [value]) [9, 8] (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 1) (TreeAccumulatorFixture.Tree.branch (TreeAccumulatorFixture.Tree.leaf 2) (TreeAccumulatorFixture.Tree.leaf 3))) = [9, 8, 1, 2, 3]) ∧ (f (fun (state : List Nat) (value : Nat) => state ++ [value]) [5] (TreeAccumulatorFixture.Tree.leaf 2) = [5, 2]) ∧ (f (fun (state : Bool) (value : Nat) => if value == 1 then !state else false) true (TreeAccumulatorFixture.Tree.leaf 1) = false) ∧ (f (fun (state : Bool) (value : Nat) => if value == 1 then !state else false) false (TreeAccumulatorFixture.Tree.leaf 1) = true)

def reference : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right state => right (left state)) input seed
theorem reference_checked : observations reference := by unfold observations; decide

def ignore_tree : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun _ seed _ => seed
theorem ignore_tree_checked : ¬ observations ignore_tree := by unfold observations; decide

def reverse_order : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right state => left (right state)) input seed
theorem reverse_order_checked : ¬ observations reverse_order := by unfold observations; decide

def left_only : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left _ => left) input seed
theorem left_only_checked : ¬ observations left_only := by unfold observations; decide

def right_only : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun _ right => right) input seed
theorem right_only_checked : ¬ observations right_only := by unfold observations; decide

def duplicate_left : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right state => right (left (left state))) input seed
theorem duplicate_left_checked : ¬ observations duplicate_left := by unfold observations; decide

def reset_at_branches : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right _ => right (left seed)) input seed
theorem reset_at_branches_checked : ¬ observations reset_at_branches := by unfold observations; decide

def reset_at_leaves : {α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ :=
fun step seed input => TreeAccumulatorFixture.foldTree (fun value _ => step seed value) (fun left right state => right (left state)) input seed
theorem reset_at_leaves_checked : ¬ observations reset_at_leaves := by unfold observations; decide

end TreeAccumulatorControls
#print axioms TreeAccumulatorFixture.foldTree
#print axioms TreeAccumulatorControls.reference
#print axioms TreeAccumulatorControls.reference_checked
#print axioms TreeAccumulatorControls.ignore_tree
#print axioms TreeAccumulatorControls.ignore_tree_checked
#print axioms TreeAccumulatorControls.reverse_order
#print axioms TreeAccumulatorControls.reverse_order_checked
#print axioms TreeAccumulatorControls.left_only
#print axioms TreeAccumulatorControls.left_only_checked
#print axioms TreeAccumulatorControls.right_only
#print axioms TreeAccumulatorControls.right_only_checked
#print axioms TreeAccumulatorControls.duplicate_left
#print axioms TreeAccumulatorControls.duplicate_left_checked
#print axioms TreeAccumulatorControls.reset_at_branches
#print axioms TreeAccumulatorControls.reset_at_branches_checked
#print axioms TreeAccumulatorControls.reset_at_leaves
#print axioms TreeAccumulatorControls.reset_at_leaves_checked
