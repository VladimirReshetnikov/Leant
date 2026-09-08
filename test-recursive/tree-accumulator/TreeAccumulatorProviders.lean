set_option autoImplicit false
namespace TreeAccumulatorFixture
set_option genSizeOf false in inductive Tree (α : Type) where | leaf : α → Tree α | branch : Tree α → Tree α → Tree α
end TreeAccumulatorFixture
def TreeAccumulatorFixture.foldTree {α ρ : Type} (leaf : α → ρ) (branch : ρ → ρ → ρ) : TreeAccumulatorFixture.Tree α → ρ | .leaf x => leaf x | .branch l r => branch (TreeAccumulatorFixture.foldTree leaf branch l) (TreeAccumulatorFixture.foldTree leaf branch r)
