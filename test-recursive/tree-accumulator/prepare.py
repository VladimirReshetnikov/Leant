"""Source-only proposal generation. Does not import or execute a live harness."""
from pathlib import Path
import hashlib
import json

OUT = Path(__file__).resolve().parent

def write(name, source):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8", newline="\n")

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

H_TYPE = "forall a s. (s -> a -> s) -> s -> Tree a -> s"
L_TYPE = "{α σ : Type} → (σ → α → σ) → σ → TreeAccumulatorFixture.Tree α → σ"
H_FOLD_TYPE = "forall a r. (a -> r) -> (r -> r -> r) -> Tree a -> r"
L_FOLD_TYPE = "{α ρ : Type} → (α → ρ) → (ρ → ρ → ρ) → TreeAccumulatorFixture.Tree α → ρ"

H_PROVIDER = """{-# LANGUAGE RankNTypes #-}
module TreeAccumulatorProviders (Tree(..), foldTree) where

data Tree a = Leaf a | Branch (Tree a) (Tree a)

foldTree :: forall a r. (a -> r) -> (r -> r -> r) -> Tree a -> r
foldTree leaf _ (Leaf x) = leaf x
foldTree leaf branch (Branch left right) =
  branch (foldTree leaf branch left) (foldTree leaf branch right)
"""
L_PROVIDER_LINES = [
    "set_option autoImplicit false",
    "namespace TreeAccumulatorFixture",
    "set_option genSizeOf false in inductive Tree (α : Type) where | leaf : α → Tree α | branch : Tree α → Tree α → Tree α",
    "end TreeAccumulatorFixture",
    "def TreeAccumulatorFixture.foldTree {α ρ : Type} (leaf : α → ρ) (branch : ρ → ρ → ρ) : TreeAccumulatorFixture.Tree α → ρ | .leaf x => leaf x | .branch l r => branch (TreeAccumulatorFixture.foldTree leaf branch l) (TreeAccumulatorFixture.foldTree leaf branch r)",
]
L_PROVIDER = "\n".join(L_PROVIDER_LINES) + "\n"

def tree(value, language):
    if isinstance(value, tuple):
        constructor = "Branch" if language == "haskell" else "TreeAccumulatorFixture.Tree.branch"
        return f"({constructor} {tree(value[0], language)} {tree(value[1], language)})"
    constructor = "Leaf" if language == "haskell" else "TreeAccumulatorFixture.Tree.leaf"
    literal = str(value)
    if isinstance(value, bool):
        literal = ("True" if value else "False") if language == "haskell" else ("true" if value else "false")
    return f"({constructor} {literal})"

# Literal expected outputs are the finite contract, not results computed by
# either the supplied fold or the candidate/witness implementations.
specifications = [
    ("singleton_seed", 2, "decimal", "7", "72"),
    ("pair_zero_seed", (1, 2), "decimal", "0", "12"),
    ("pair_nonzero_seed", (1, 2), "decimal", "7", "712"),
    ("pair_second_seed", (1, 2), "decimal", "37", "3712"),
    ("left_associated", ((1, 2), 3), "decimal", "7", "7123"),
    ("right_associated", (1, (2, 3)), "decimal", "7", "7123"),
    ("balanced_four", ((1, 2), (3, 4)), "decimal", "7", "71234"),
    ("asymmetric_four", (1, ((2, 3), 4)), "decimal", "7", "71234"),
    ("deep_five", (1, (2, (3, (4, 5)))), "decimal", "7", "712345"),
    ("nonlinear_state", (1, (2, 3)), "square", "2", "732"),
    ("nonlinear_second_seed", ((1, 2), 3), "square", "3", "10407"),
    ("boolean_elements", (True, (False, False)), "bits", "3", "28"),
    ("sequence_accumulator", (1, (2, 3)), "sequence", "[9, 8]", "[9, 8, 1, 2, 3]"),
    ("sequence_singleton", 2, "sequence", "[5]", "[5, 2]"),
    ("boolean_accumulator_true", 1, "toggle", "True", "False"),
    ("boolean_accumulator_false", 1, "toggle", "False", "True"),
]
H_STEPS = {
    "decimal": "(\\state value -> (10 * state + value :: Int))",
    "square": "(\\state value -> (state * state + value :: Int))",
    "bits": "(\\state value -> (2 * state + (if value then 1 else 0) :: Int))",
    "sequence": "(\\state value -> state ++ [value :: Int])",
    "toggle": "(\\state value -> if (value :: Int) == 1 then not state else False)",
}
L_STEPS = {
    "decimal": "(fun (state value : Nat) => 10 * state + value)",
    "square": "(fun (state value : Nat) => state * state + value)",
    "bits": "(fun (state : Nat) (value : Bool) => 2 * state + (if value then 1 else 0))",
    "sequence": "(fun (state : List Nat) (value : Nat) => state ++ [value])",
    "toggle": "(fun (state : Bool) (value : Nat) => if value == 1 then !state else false)",
}
observations = []
for name, shape, step, seed, expected in specifications:
    l_seed = seed.replace("True", "true").replace("False", "false")
    l_expected = expected.replace("True", "true").replace("False", "false")
    observations.append(dict(
        name=name,
        haskell=f"{{f}} {H_STEPS[step]} {seed} {tree(shape, 'haskell')} == {expected}",
        lean=f"{{f}} {L_STEPS[step]} {l_seed} {tree(shape, 'lean')} = {l_expected}",
    ))
H_PREDICATE = " && ".join("(" + item["haskell"] + ")" for item in observations)
L_PREDICATE = " ∧ ".join("(" + item["lean"] + ")" for item in observations)

# Every control has the entire polymorphic requested type. In particular,
# reset_at_branches captures the actual caller's seed; it invents no value of s.
controls = [
    dict(name="reference", passes=True,
         haskell="\\step seed input -> foldTree (\\value state -> step state value) (\\left right state -> right (left state)) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right state => right (left state)) input seed"),
    dict(name="ignore_tree", passes=False, haskell="\\_ seed _ -> seed", lean="fun _ seed _ => seed"),
    dict(name="reverse_order", passes=False,
         haskell="\\step seed input -> foldTree (\\value state -> step state value) (\\left right state -> left (right state)) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right state => left (right state)) input seed"),
    dict(name="left_only", passes=False,
         haskell="\\step seed input -> foldTree (\\value state -> step state value) (\\left _ -> left) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left _ => left) input seed"),
    dict(name="right_only", passes=False,
         haskell="\\step seed input -> foldTree (\\value state -> step state value) (\\_ right -> right) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun _ right => right) input seed"),
    dict(name="duplicate_left", passes=False,
         haskell="\\step seed input -> foldTree (\\value state -> step state value) (\\left right state -> right (left (left state))) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right state => right (left (left state))) input seed"),
    dict(name="reset_at_branches", passes=False,
         haskell="\\step seed input -> foldTree (\\value state -> step state value) (\\left right _ -> right (left seed)) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value state => step state value) (fun left right _ => right (left seed)) input seed"),
    dict(name="reset_at_leaves", passes=False,
         haskell="\\step seed input -> foldTree (\\value _ -> step seed value) (\\left right state -> right (left state)) input seed",
         lean="fun step seed input => TreeAccumulatorFixture.foldTree (fun value _ => step seed value) (fun left right state => right (left state)) input seed"),
]

write("TreeAccumulatorProviders.hs", H_PROVIDER)
write("TreeAccumulatorProviders.lean", L_PROVIDER)
h_checks = ["{-# LANGUAGE RankNTypes #-}", "module TreeAccumulatorControls where",
            "import TreeAccumulatorProviders (Tree(..), foldTree)", "", "observations :: (" + H_TYPE + ") -> [(String, Bool)]",
            "observations f =", "  [ " + "\n  , ".join(
                '(' + json.dumps(item["name"]) + ', ' + item["haskell"].format(f="f") + ')'
                for item in observations) + "\n  ]", ""]
for control in controls:
    h_checks += [control["name"] + " :: " + H_TYPE, control["name"] + " = " + control["haskell"], ""]
h_checks += ["controlResults :: [(String, Bool)]", "controlResults =", "  [ " + "\n  , ".join(
    '(' + json.dumps(control["name"]) + ', ' + ("" if control["passes"] else "not $ ") +
    "all snd (observations " + control["name"] + "))" for control in controls) + "\n  ]", ""]
write("TreeAccumulatorControls.hs", "\n".join(h_checks))
write("CheckControls.hs", """module Main where
import TreeAccumulatorControls (controlResults)
main :: IO ()
main = do
  print controlResults
  if all snd controlResults then pure () else fail "tree accumulator control failure"
""")
lean_checks = [L_PROVIDER.rstrip(), "namespace TreeAccumulatorControls", "def observations (f : " + L_TYPE + ") : Prop :=",
               L_PREDICATE.format(f="f"), ""]
for control in controls:
    lean_checks += ["def " + control["name"] + " : " + L_TYPE + " :=", control["lean"],
                   "theorem " + control["name"] + "_checked : " + ("" if control["passes"] else "¬ ") + "observations " + control["name"] + " := by unfold observations; decide", ""]
lean_checks += ["end TreeAccumulatorControls", "#print axioms TreeAccumulatorFixture.foldTree"]
for control in controls:
    lean_checks += ["#print axioms TreeAccumulatorControls." + control["name"],
                    "#print axioms TreeAccumulatorControls." + control["name"] + "_checked"]
write("TreeAccumulatorControls.lean", "\n".join(lean_checks) + "\n")
write("HaskellCandidateReplay.hs.in", """{-# LANGUAGE RankNTypes, ImpredicativeTypes, ScopedTypeVariables, TypeApplications #-}
module Main where
import TreeAccumulatorProviders (Tree(..), foldTree)
import TreeAccumulatorControls (observations)

candidate :: """ + H_TYPE + "\ncandidate = __EXACT_SYNTHESIZED_TERM__\n\nmain :: IO ()\nmain = do\n  print (observations candidate)\n  if all snd (observations candidate) then pure () else fail \"candidate failed original finite predicate\"\n")
write("LeanCandidateReplay.lean.in", L_PROVIDER + "\ndef TreeAccumulatorReplay.candidate : " + L_TYPE +
      " :=\n__EXACT_SYNTHESIZED_TERM__\n\ntheorem TreeAccumulatorReplay.candidate_passes :\n" +
      L_PREDICATE.format(f="TreeAccumulatorReplay.candidate") + " := by decide\n\n" +
      "#print axioms TreeAccumulatorFixture.foldTree\n#print axioms TreeAccumulatorReplay.candidate\n#print axioms TreeAccumulatorReplay.candidate_passes\n")

settings = [":set synth-library off", ":set synth-classical off", ":set synth-providers on", ":set synth-debug on",
            ":set synth-ranking balanced", ":set synth-shown 1", ":set synth-djinn-strategy interleave",
            ":set synth-provider-cap 80", ":set synth-window 1024", ":set synth-verify 1024",
            ":set synth-steps 100000", ":set synth-budget 100000", ":set synth-timeout 90"]
cells = []
for engine in ("djinn", "exference", "both"):
    for false_control in (False, True):
        name = "tree_accumulator_" + engine + ("_reject_all" if false_control else "")
        # The false query is always inhabited without needing a productive fold
        # search; it must nevertheless produce an actual false observation.
        target = "{α : Type} → TreeAccumulatorFixture.Tree α → TreeAccumulatorFixture.Tree α" if false_control else L_TYPE
        predicate = "False" if false_control else L_PREDICATE.format(f=name)
        command = f":synth {name} : {target} where {predicate}"
        source = "\n".join([*settings, ":set synth-engine " + engine, *L_PROVIDER_LINES, command, ":quit", ""])
        filename = "commands/" + name + ".commands.txt"
        write(filename, source)
        cells.append(dict(name=name, engine=engine, expected="actual_false" if false_control else "candidate",
                          path=filename, sha256=digest(OUT / filename), type=target,
                          predicate_sha256=hashlib.sha256(predicate.encode("utf-8")).hexdigest()))

project = OUT.parents[1]
base_paths = [project / "test-recursive/run_recursors.py",
              project / "lib/Djex/test-integration/RecursorSpec.hs"]

write("case.json", json.dumps(dict(
    status="specification_only", operation="treeAccumulateLeft", observation_count=len(observations),
    haskell_type=H_TYPE, lean_type=L_TYPE, haskell_fold_type=H_FOLD_TYPE, lean_fold_type=L_FOLD_TYPE,
    haskell_predicate=H_PREDICATE, lean_predicate=L_PREDICATE, observations=observations,
    controls=controls, cells=cells,
    provider_policy=dict(haskell_value_providers=["foldTree"], haskell_datatype="Tree a = Leaf a | Branch (Tree a) (Tree a)",
                         lean_value_providers=["TreeAccumulatorFixture.foldTree"],
                         lean_constructor_providers=["TreeAccumulatorFixture.Tree.leaf", "TreeAccumulatorFixture.Tree.branch"],
                         required_in_positive_candidate="TreeAccumulatorFixture.foldTree", generated_equality_providers=[],
                         genSizeOf=False, oracle_modules_loaded_for_search=False),
    limits=dict(haskell_djinn=dict(raw_candidates=1024, choices=100000, strategy="Interleave"),
                haskell_exference=dict(raw_candidates=1024, steps=100000, queue=1024, allow_unused=True, multi_constructor_patterns=True),
                haskell_independent_replay_seconds=60, haskell_probe_outer_guard_seconds=180,
                helper_build_outer_guard_seconds=180,
                lean=dict(window=1024, verify=1024, steps=100000, choices=100000, provider_cap=80, strategy="interleave",
                          shown=1, command_seconds=90, fresh_process_guard_seconds=180)),
    preparation_bases=[dict(path=path.relative_to(project).as_posix(), sha256=digest(path)) for path in base_paths],
), indent=2, ensure_ascii=False) + "\n")

generated = sorted(path for path in OUT.rglob("*") if path.is_file() and path.name not in ("manifest.json",) and "__pycache__" not in path.parts)
write("manifest.json", json.dumps(dict(status="specification_only", runtime_validation="not run",
    files=[dict(path=path.relative_to(OUT).as_posix(), bytes=path.stat().st_size, sha256=digest(path)) for path in generated]), indent=2) + "\n")
