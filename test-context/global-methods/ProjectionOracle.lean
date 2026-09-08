-- Append to the exact production prelude emitted by the freshly built unit executable.
-- These metadata controls never enter any live search session.
class ProjectionControl.C (α : Type) where out : Nat
structure ProjectionControl.NotClass (α : Type) where out : Nat
class ProjectionControl.Parent (α : Type) where parentOut : Nat
class ProjectionControl.Child (α : Type) extends ProjectionControl.Parent α where out : Nat
def ProjectionControl.C.sibling : Nat := 99

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let direct := LeantSynth.contextSessionClassProjections env ["ProjectionControl.C"]
  unless direct.toList == [`ProjectionControl.C.out] do
    throwError "class projection inventory differs from its actual direct field"
  let ordinary := LeantSynth.contextSessionClassProjections env ["ProjectionControl.NotClass"]
  unless ordinary.isEmpty do
    throwError "ordinary structure acquired class-method priority"
  let sibling := LeantSynth.contextSessionClassProjections env ["ProjectionControl.C.sibling", "ProjectionControl"]
  unless sibling.isEmpty do
    throwError "namespace or sibling name acquired class-method priority"
  let child := LeantSynth.contextSessionClassProjections env ["ProjectionControl.Child"]
  unless child.toList == [`ProjectionControl.Child.out] do
    throwError "superclass subobject or unrelated projection entered the direct-method inventory"
  logInfo "PROJECTION_METADATA_CONTROLS_PASSED_4"

#print axioms ProjectionControl.C
#print axioms ProjectionControl.C.out
#print axioms ProjectionControl.NotClass
#print axioms ProjectionControl.Parent
#print axioms ProjectionControl.Child
#print axioms ProjectionControl.Child.out
