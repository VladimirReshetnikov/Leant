set_option autoImplicit false
class Ctx.C (α : Type) where out : Nat

def MethodOracle.reference : ∀ (α : Type), [Ctx.C α] → Nat :=
  fun (α : Type) [dictionary : Ctx.C α] => @Ctx.C.out α dictionary

theorem MethodOracle.reference_passes :
    (@MethodOracle.reference Nat (@Ctx.C.mk Nat 7) = 7) ∧
    (@MethodOracle.reference Nat (@Ctx.C.mk Nat 11) = 11) ∧
    (@MethodOracle.reference Bool (@Ctx.C.mk Bool 11) = 11) ∧
    (@MethodOracle.reference Bool (@Ctx.C.mk Bool 7) = 7) := by decide

def MethodOracle.wrong_dictionary : ∀ (α : Type), [Ctx.C α] → Nat :=
  fun (α : Type) [_dictionary : Ctx.C α] => @Ctx.C.out α (@Ctx.C.mk α 7)

theorem MethodOracle.wrong_dictionary_rejected :
    ¬ (@MethodOracle.wrong_dictionary Nat (@Ctx.C.mk Nat 11) = 11) := by decide

#print axioms Ctx.C
#print axioms Ctx.C.mk
#print axioms Ctx.C.out
#print axioms MethodOracle.reference
#print axioms MethodOracle.reference_passes
#print axioms MethodOracle.wrong_dictionary
#print axioms MethodOracle.wrong_dictionary_rejected
