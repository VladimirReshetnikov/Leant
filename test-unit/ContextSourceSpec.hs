-- | Real production preparation/cursor boundaries for exact local-Given
-- source packets. These tests do not claim that the generated Lean serializer
-- or displayed terms have passed Lean; the live command/replay suite owns that
-- separate acceptance boundary.
module ContextSourceSpec (tests) where

import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM_)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Language.Haskell.Djex as D
import Leant.Json (JValue (..), encodeJson, jLookup, parseJson)
import Leant.Synth.CandidateObservation (candidateAcceptanceObservation)
import Leant.Synth.ContextSource
import Leant.Synth.Engine
import Leant.Synth.Fragment
import Leant.Synth.Observability
  ( CandidateRenderingRoute (RouteLegacyCandidateFallback, RouteTypedCandidate, RouteUnobserved) )
import Leant.Synth.Length.Integration (assessLengthVerificationBatch, disabledLengthAssessmentMode)
import Leant.Synth.Length.Presentation
  ( lengthCandidatePresentationText, lengthCandidatePresentationVariant, presentLengthAssessment )
import Leant.Synth.Verification (VariantVerdict (VariantAccepted), verifyCandidateGroups)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, assertFailure, testCase)

tests :: TestTree
tests = testGroup "Production lexical Given source metadata"
  ([ testCase (label ++ " " ++ show engine ++ " streaming=" ++ show streaming) $ do
       parsed <- expectRight $ parseGoalSexp $ packet source
       metadata <- requireMetadata parsed
       pgFrag parsed @?= contextSourceFragment metadata
       let limits = defaultSynthLimits
             { synthLimitWindow = 8, synthLimitBudget = Just 1024 }
           outcome = synthesizeContextualWithProvidersSkippingDetailedWith
             streaming limits engine 1024 Set.empty [] metadata $ pgFrag parsed
       step <- expectRight $ advanceDetailedSynthCursor 1 $ startDetailedSynthCursor outcome
       groups <- case step of
         DetailedSynthCursorCandidateBatch batch _ -> pure $ detailedCandidateBatchGroups batch
         DetailedSynthCursorEngineFailed failure -> fail failure
         DetailedSynthCursorNoTerm notes -> fail $ "no contextual candidate: " ++ show notes
         _ -> fail "contextual production cursor returned no checked candidate"
       length groups @?= 1
       forM_ groups $ \group -> do
         detailedCandidateGroupRoute group @?= RouteTypedCandidate
         assertBool "production context renderer did not display its explicit dictionary/type annotation" $
           all ("leant" `isInfixOf`) $ detailedCandidateGroupVariants group
         authority <- maybe (fail "candidate lost its source-owned authority") pure $
           detailedCandidateGroupSourceAuthority group
         candidateSourceAuthorityEngine authority @?= engine
         foldCandidateSourceAuthority
           (\owned -> inspectCandidate requiresApplication $ djinnSourceCandidate owned)
           (\owned -> inspectCandidate requiresApplication $ typedCandidateSemanticCandidate owned)
           authority
         forM_ (detailedCandidateGroupVerificationVariants group) $ \variant -> do
           assertBool "verification variant changed its source authority" $
             detailedVerificationVariantSourceAuthority variant == Just authority
           origin <- maybe (fail "candidate lost its exact context renderer origin") pure $
             detailedVerificationVariantExactTypedOrigin variant
           renderExactTypedVariantOrigin origin @?= Right (detailedCandidateGroupVariants group)
         inspectPresentation engine group
   | (label, source, requiresApplication) <- fixtures
   , engine <- [EngineDjinn, EngineExference]
   , streaming <- [False, True]
   ] ++
   [ testCase "ordinary contextual Exference collects incrementally with strict owned request" $ do
       parsed <- expectRight $ parseGoalSexp $ packet $ sourceOf "exact forwarding"
       metadata <- requireMetadata parsed
       let steps = 20000
           limits = defaultSynthLimits
             { synthLimitWindow = 32, synthLimitTried = 32, synthLimitShown = 1
             , synthLimitQueue = 73, synthLimitBudget = Just 20000 }
       outcome <- expectRight $ synthesizeContextualWithProvidersSkippingDetailedWith
         False limits EngineExference steps Set.empty [] metadata $ pgFrag parsed
       case outcome of
         DetailedSynthStreaming{} -> pure ()
         _ -> assertFailure "ordinary contextual forwarding collected a complete ranked pool"
       -- The command may request its full verification allowance; a streaming
       -- cursor still returns one group and leaves the remaining search alone.
       step <- expectRight $ advanceDetailedSynthCursorWith 32 32 $
         startDetailedSynthCursor $ Right outcome
       _ <- evaluate $ forceDetailedSynthCursorStep step
       group <- case step of
         DetailedSynthCursorCandidateBatch batch _ -> case detailedCandidateBatchGroups batch of
           [owned] -> pure owned
           _ -> fail "ordinary context cursor forced more than its first group"
         _ -> fail "ordinary contextual forwarding returned no candidate"
       detailedCandidateGroupRoute group @?= RouteTypedCandidate
       semantic <- maybe (fail "ordinary cursor lost Exference request authority") pure $
         detailedCandidateGroupSemanticSidecar group
       let authority = typedCandidateSemanticAuthorityInspection semantic
           request = inspectedAuthorityRequest authority
           options = D.requestOptions request
       D.exferenceAllowUnused options @?= False
       D.exferenceMaximumSteps options @?= steps
       D.exferenceMaximumQueueSize options @?= Just (synthLimitQueue limits)
       D.exferenceCandidateRanking options @?= synthLimitRanking limits
       D.exferenceConstraintDeferralSteps options @?=
         D.exferenceConstraintDeferralSteps D.defaultExferenceOptions
       D.exferenceAllowResidualConstraints options @?= False
       D.exferenceProviderCosts options @?= Map.empty
       D.requestContexts request @?= []
       D.requestGoal request @?= inspectedAuthorityConvertedSourceGoal authority
       inspectedAuthorityProviderAssignments authority @?= []
       graph <- expectRight $ D.typedCandidateTermGraph $ typedCandidateSemanticCandidate semantic
       root <- maybe (fail "ordinary candidate has no graph root") pure $
         D.lookupTermNode (D.termGraphRoot graph) graph
       assertBool "ordinary candidate graph belongs to another request" $
         D.alphaEquivalentClosedTypes (D.requestGoal request) (D.termNodeType root)
       inspectCandidate False $ typedCandidateSemanticCandidate semantic
       inspectPresentation EngineExference group
   , testCase "ordinary contextual Both verifies its own first group before an opposing tail" $ do
       parsed <- expectRight $ parseGoalSexp $ packet $ sourceOf "exact forwarding"
       metadata <- requireMetadata parsed
       let limits = defaultSynthLimits
             { synthLimitWindow = 32, synthLimitTried = 32, synthLimitShown = 1
             , synthLimitBudget = Just 20000 }
           ordinary engine = synthesizeContextualWithProvidersSkippingDetailedWith
             False limits engine 20000 Set.empty [] metadata $ pgFrag parsed
       actualBoth <- expectRight $ ordinary EngineBoth
       firstDjinn <- expectRight $ ordinary EngineDjinn
       let poisoned = mergeDetailedOutcomesSkipping Set.empty firstDjinn $
             deferDetailedOutcome $ error "ordinary contextual Both demanded an unobserved opposing search"
       forM_ [actualBoth, poisoned] $ \outcome -> do
         case outcome of
           DetailedSynthStreaming{} -> pure ()
           _ -> assertFailure "ordinary contextual Both retained eager pooled collection"
         step <- expectRight $ advanceDetailedSynthCursorWith 32 32 $
           startDetailedSynthCursor $ Right outcome
         _ <- evaluate $ forceDetailedSynthCursorStep step
         group <- case step of
           DetailedSynthCursorCandidateBatch batch _ -> case detailedCandidateBatchGroups batch of
             [owned] -> pure owned
             _ -> fail "Both cursor returned more than one owned group"
           _ -> fail "Both contextual cursor returned no candidate"
         authority <- maybe (fail "Both group lost its source authority") pure $
           detailedCandidateGroupSourceAuthority group
         candidateSourceAuthorityEngine authority @?= EngineDjinn
         inspectPresentation EngineDjinn group
   , testCase "debug serialization of a Both compatibility survivor does not recover an unobserved origin" $
       forM_ [RouteLegacyCandidateFallback, RouteUnobserved] $ \route -> do
         let compatibility = detailedCandidateGroup route ["accepted compatibility term"]
             opposing = detailedCandidateGroup RouteUnobserved ["different term"] :
               error "debug display demanded the unobserved Exference assessment-origin tail"
             combined = mergeDetailedCandidateGroups [compatibility] opposing
         accepted <- verifyCandidateGroups 1 (const $ pure VariantAccepted)
           (map detailedCandidateGroupVerificationVariants combined)
         assessed <- assessLengthVerificationBatch disabledLengthAssessmentMode accepted
         presentation <- case presentLengthAssessment assessed of
           [retained] -> pure retained
           _ -> fail "Both survivor lost its quota-bounded presentation receipt"
         serialized <- evaluate $ force $ encodeJson $ candidateAcceptanceObservation 1 $
           lengthCandidatePresentationVariant presentation
         decoded <- expectRight $ parseJson serialized
         jLookup "term" decoded @?= Just (JStr "accepted compatibility term")
         jLookup "route" decoded @?= Just (JStr $ show route)
         jLookup "origin" decoded @?= Just JNull
   , testCase "ordinary context-free wire keeps the existing route" $ do
       parsed <- expectRight $ parseGoalSexp "(goal type (query (roots) (head)) (all \"a\" (-> (var \"a\") (var \"a\"))))"
       parsedGoalContextSource parsed @?= Nothing
   , testCase "legacy contextual wire explicitly lacks source metadata" $ do
       parsed <- expectRight $ parseGoalSexp "(goal type (query (roots) (head)) (inst \"C Nat\" (atom unsafe \"Nat\")))"
       assertUnsupported parsed
   , testCase "unsupported or malformed contextual packets never become legacy goals" $
       forM_ [ "unsupported \"Prop binder\"", "2 (var \"a\")"
             , "1 (all strict-implicit \"a\" (var \"a\"))"
             , "1 (given (name \"C\") 1 (args (var \"unbound\")) (var \"unbound\"))"
             ] $ \payload -> do
         parsed <- expectRight $ parseGoalSexp $
           "(goal type (query (roots) (head)) (atom unsafe \"legacy\") (context-source " ++ payload ++ "))"
         assertUnsupported parsed
   , testCase "exact source refuses a changed fragment before search" $ do
       parsed <- expectRight $ parseGoalSexp $ packet $ sourceOf "unused root"
       metadata <- requireMetadata parsed
       case synthesizeContextualWithProvidersSkippingDetailedWith False defaultSynthLimits
           EngineExference 0 Set.empty [] metadata FTop of
         Left failure -> assertBool "missing source mismatch diagnostic" $ "packet does not own" `isInfixOf` failure
         Right _ -> assertFailure "unrelated fragment acquired source metadata"
   , testCase "ambient provider inventory needs its own complete source packets" $ do
       parsed <- expectRight $ parseGoalSexp $ packet $ sourceOf "unused root"
       metadata <- requireMetadata parsed
       forM_ [False, True] $ \streaming ->
         case synthesizeContextualWithProvidersSkippingDetailedWith streaming defaultSynthLimits
             EngineDjinn 0 Set.empty [ProviderFrag "unrelated" FTop] metadata (pgFrag parsed) of
           Left failure -> assertBool "missing provider metadata diagnostic" $ "provider inventory" `isInfixOf` failure
           Right _ -> assertFailure "ambient provider silently entered exact context search"
   , testCase "a source class identity cannot also become a nominal type" $ do
       let source = ContextForall ContextExplicit "a" $
             ContextGiven ["C"] 1 [ContextVariable "a"] $
               ContextNominal ["C"] 1 [ContextVariable "a"]
       case mkContextSource source of
         Left failure -> assertBool "missing class/nominal identity diagnostic" $ "class identity" `isInfixOf` failure
         Right _ -> assertFailure "class and nominal authority were conflated"
   ])

fixtures :: [(String, String, Bool)]
fixtures =
  [ ("unused root", all' "a" $ given "a" $ arrow (var "a") (var "a"), False)
  , ("nested callback", arrow (arrow identityScheme token) token, False)
  , ("exact forwarding", arrow tokenScheme tokenScheme, False)
  , ("forced local Given", all' "a" $ given "a" $ arrow tokenScheme $ arrow (var "a") token, True)
  ]
 where
  identityScheme = all' "b" $ given "b" $ arrow (var "b") (var "b")
  tokenScheme = all' "b" $ given "b" $ arrow (var "b") token

sourceOf :: String -> String
sourceOf label = case [source | (name, source, _) <- fixtures, name == label] of
  [source] -> source
  _ -> error "missing source fixture"

packet :: String -> String
packet source = "(goal type (query (roots \"ContextFixture\") (head)) (atom unsafe \"legacy\") (context-source 1 " ++ source ++ "))"

all' :: String -> String -> String
all' variable body = "(all explicit " ++ show variable ++ " " ++ body ++ ")"
given :: String -> String -> String
given variable body = "(given (name \"ContextFixture\" \"C\") 1 (args " ++ var variable ++ ") " ++ body ++ ")"
var :: String -> String
var variable = "(var " ++ show variable ++ ")"
arrow :: String -> String -> String
arrow a b = "(arrow " ++ a ++ " " ++ b ++ ")"
token :: String
token = "(nominal (name \"ContextFixture\" \"Token\") 0 (args))"

requireMetadata :: ParsedGoal -> IO ContextSource
requireMetadata parsed = case parsedGoalContextSource parsed of
  Just (Right source) -> pure source
  other -> fail $ "missing supported source metadata: " ++ show other

assertUnsupported :: ParsedGoal -> IO ()
assertUnsupported parsed = case parsedGoalContextSource parsed of
  Just (Left failure) -> assertBool "empty source refusal" $ not $ null failure
  _ -> assertFailure "unsupported contextual source used the legacy route"

inspectCandidate
  :: (Ord variable, Eq local, Show local, Show absence)
  => Bool
  -> D.TypedCandidate absence (D.Type variable) local
       (D.Candidate sourceType details (D.FunctionClause local))
  -> IO ()
inspectCandidate requiresApplication candidate = do
  graph <- expectRight $ D.typedCandidateTermGraph candidate
  let clause = D.candidateOutput $ D.typedCandidateCompatibility candidate
  D.eraseTermGraphToFunctionClause (D.clauseName clause) graph @?= clause
  root <- maybe (fail "checked graph has no source root") pure $
    D.lookupTermNode (D.termGraphRoot graph) graph
  assertBool "source metadata produced an open graph root" $
    Set.null $ D.freeVariables $ D.termNodeType root
  let forms = map (D.termNodeForm . snd) $ D.termGraphNodes graph
      applications = [witness | D.TypedContextApplication _ _ witness <- forms]
      introductions =
        [ D.contextEvidenceBinder $ D.givenContextEvidence occurrence slot
        | D.TypedContextIntroduction occurrence _ witness <- forms
        , (slot, _) <- zip [0 ..] $ D.contextIntroductionConstraints witness
        ]
  forM_ [() | D.TypedGlobal{} <- forms] $ \_ ->
    assertFailure "a source packet with no providers acquired a global value"
  if requiresApplication then assertBool "forced local source lost its Given application" $
    not $ null applications
    else pure ()
  forM_ applications $ \witness -> forM_ (D.contextApplicationEvidence witness) $ \evidence ->
    assertBool "dictionary use lost its actual introduction identity" $
      D.contextEvidenceBinder evidence `elem` introductions

expectRight :: Show failure => Either failure value -> IO value
expectRight = either (fail . show) pure

-- Callback acceptance here is a unit boundary only; the production runner
-- separately obtains real Lean acceptance and full-type/payload replay.
inspectPresentation :: SynthEngine -> DetailedCandidateGroup -> IO ()
inspectPresentation engine group = do
  original <- present group
  let variant = lengthCandidatePresentationVariant original
      observation = candidateAcceptanceObservation 1 variant
  _ <- evaluate $ force $ encodeJson observation
  assertBool "presentation changed the accepted variant's complete source authority" $
    detailedVerificationVariantSourceAuthority variant == detailedCandidateGroupSourceAuthority group
  case detailedCandidateGroupVerificationVariants group of
    first : _ -> assertBool "presentation changed the accepted renderer occurrence" $
      detailedVerificationVariantExactTypedOrigin variant == detailedVerificationVariantExactTypedOrigin first
    [] -> fail "production fixture has no verification variants"
  lengthCandidatePresentationText original @?= detailedVerificationVariantText variant
  jLookup "term" observation @?= Just (JStr $ lengthCandidatePresentationText original)
  jLookup "route" observation @?= Just (JStr "RouteTypedCandidate")
  origin <- requireField "origin" observation
  jLookup "engine" origin @?= Just (JStr $ synthEngineName engine)
  rendering <- requireField "rendering" origin
  jLookup "term" rendering @?= jLookup "term" observation
  jLookup "matches_verified_text" rendering @?= Just (JBool True)
  graph <- requireField "graph" origin
  jLookup "root_closed" graph @?= Just (JBool True)
  jLookup "erasure_matches_compatibility" graph @?= Just (JBool True)
  jLookup "globals" graph @?= Just (JArr [])
  -- An arbitrary text wrapper keeps the legacy route tag but explicitly loses
  -- origin authority. Neither the presentation nor its debug observation may
  -- reattach the earlier graph, even if the wrapped term is later accepted.
  wrapped <- present $ mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
    (\text -> "(" ++ text ++ ")") group
  let changed = candidateAcceptanceObservation 1 $ lengthCandidatePresentationVariant wrapped
  jLookup "term" changed @?= Just (JStr $ "(" ++ lengthCandidatePresentationText original ++ ")")
  jLookup "route" changed @?= Just (JStr "RouteTypedCandidate")
  jLookup "origin" changed @?= Just JNull
  -- Even identical text cannot recover a deliberately dropped authority by
  -- looking it up in a previous candidate or an aggregate rendering count.
  sameText <- present $ mapDetailedCandidateGroupVariantsDroppingSemanticSidecar id group
  let unowned = candidateAcceptanceObservation 1 $ lengthCandidatePresentationVariant sameText
  jLookup "term" unowned @?= jLookup "term" observation
  jLookup "route" unowned @?= Just (JStr "RouteTypedCandidate")
  jLookup "origin" unowned @?= Just JNull
 where
  present candidateGroup = do
    accepted <- verifyCandidateGroups 1 (const $ pure VariantAccepted)
      [detailedCandidateGroupVerificationVariants candidateGroup]
    assessed <- assessLengthVerificationBatch disabledLengthAssessmentMode accepted
    case presentLengthAssessment assessed of
      [presentation] -> pure presentation
      _ -> fail "verified contextual group lost its exact presentation receipt"
  requireField name value = maybe (fail $ "missing observation field " ++ name) pure $ jLookup name value
