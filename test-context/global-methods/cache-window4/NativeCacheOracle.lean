set_option autoImplicit false
class Ctx.C (α : Type) where out : Nat

def NativeCacheOracle.reference : ∀ (α : Type), Ctx.C α → Nat :=
  fun α dictionary => Nat.add (@Ctx.C.out α dictionary) (@Ctx.C.out α dictionary)

theorem NativeCacheOracle.reference_passes :
    (@NativeCacheOracle.reference Nat (@Ctx.C.mk Nat 7) = 14) ∧
    (@NativeCacheOracle.reference Nat (@Ctx.C.mk Nat 11) = 22) ∧
    (@NativeCacheOracle.reference Bool (@Ctx.C.mk Bool 11) = 22) ∧
    (@NativeCacheOracle.reference Bool (@Ctx.C.mk Bool 7) = 14) := by decide

def NativeCacheOracle.projection : ∀ (α : Type), Ctx.C α → Nat :=
  fun α dictionary => @Ctx.C.out α dictionary

theorem NativeCacheOracle.projection_rejected :
    ¬ (@NativeCacheOracle.projection Nat (@Ctx.C.mk Nat 7) = 14) := by decide

#print axioms Ctx.C
#print axioms Ctx.C.mk
#print axioms Ctx.C.out
#print axioms NativeCacheOracle.reference
#print axioms NativeCacheOracle.reference_passes
#print axioms NativeCacheOracle.projection
#print axioms NativeCacheOracle.projection_rejected
