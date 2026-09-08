-- Full source schemes and exact provider ownership through contextual search.
module GlobalContextProviderSpec (tests) where

import Control.Monad (forM_)
import Data.List (isInfixOf)
import qualified Data.Set as Set
import qualified Language.Haskell.Djex as D
import Leant.Synth.ContextSource
import Leant.Synth.Engine
import Leant.Synth.Fragment
import Leant.Synth.Observability (CandidateRenderingRoute (RouteTypedCandidate))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, assertFailure, testCase)

tests :: TestTree
tests = testGroup "Complete global contextual provider source"
  ([ testCase ("forced method " ++ show engine ++ " behavioral=" ++ show behavioral) $ do
       source <- goalSource methodGoal
       providers <- right $ parseProviderSexp methodProvider
       outcome <- right $ synthesizeContextualWithProvidersSkippingDetailedWith
         behavioral limits engine 20000 Set.empty providers source $ contextSourceFragment source
       step <- right $ advanceDetailedSynthCursorWith 32 32 $ startDetailedSynthCursor $ Right outcome
       group <- case step of
         DetailedSynthCursorCandidateBatch batch _ -> case detailedCandidateBatchGroups batch of
           [owned] -> pure owned
           _ -> fail "contextual provider cursor changed one-group admission"
         DetailedSynthCursorEngineFailed failure -> fail failure
         _ -> fail "forced method produced no checked group"
       detailedCandidateGroupRoute group @?= RouteTypedCandidate
       owner <- maybe (fail "missing exact provider source owner") pure $ detailedCandidateGroupSourceAuthority group
       assertBool "wrong backend donated provider authority" $
         engine == EngineBoth || candidateSourceAuthorityEngine owner == engine
       foldCandidateSourceAuthority
         (inspect . djinnSourceCandidate)
         (inspect . typedCandidateSemanticCandidate) owner
       forM_ (detailedCandidateGroupVerificationVariants group) $ \variant -> do
         assertBool "method global was replaced by a bare name or another provider" $
           "@_root_.«Ctx».«C».«out»" `isInfixOf` detailedVerificationVariantText variant
         origin <- maybe (fail "missing exact renderer owner") pure $ detailedVerificationVariantExactTypedOrigin variant
         renderExactTypedVariantOrigin origin @?= Right (detailedCandidateGroupVariants group)
   | engine <- [EngineDjinn, EngineExference, EngineBoth]
   , behavioral <- [False, True]
   ] ++
   [ testCase "a legacy provider cannot acquire complete source authority" $ do
       source <- goalSource identityGoal
       reject source [ProviderFrag "Ctx.C.out" (contextSourceFragment source)]
   , testCase "an unsupported universe packet is not silently dropped for identity" $ do
       source <- goalSource identityGoal
       providers <- right $ parseProviderSexp
         "(providers (context-provider \"Ctx.C.out\" (name \"Ctx\" \"C\" \"out\") unsupported \"provider constant has unretained universe parameters\"))"
       reject source providers
   , testCase "structured provider owner cannot be changed independently" $ do
       source <- goalSource identityGoal
       providers <- right $ parseProviderSexp methodProvider
       case providers of
         [ProviderFragWithContextSource name fragment _ metadata] ->
           reject source [ProviderFragWithContextSource name fragment ["Other", "out"] metadata]
         _ -> fail "expected one exact source provider"
   , testCase "a repeated foreign provider owner is rejected during actual preparation" $ do
       source <- goalSource identityGoal
       providers <- right $ parseProviderSexp methodProvider
       rejectDeferred source (providers ++ providers)
   , testCase "a provider packet cannot substitute a namespace sibling owner" $ do
       source <- goalSource identityGoal
       providers <- right $ parseProviderSexp methodProvider
       case providers of
         [ProviderFragWithContextSource _ fragment parts metadata] ->
           reject source [ProviderFragWithContextSource "Ctx.C.other" fragment parts metadata]
         _ -> fail "expected one exact source provider"
   , testCase "the packet preserves independent explicit and implicit source binders" $ do
       providers <- right $ parseProviderSexp methodProvider
       case providers of
         [ProviderFragWithContextSource _ _ _ (Right metadata)] ->
           case contextSourceType metadata of
             ContextForall ContextImplicit "a" (ContextGiven ["Ctx", "C"] 1 [ContextVariable "a"] _) -> pure ()
             _ -> assertFailure "complete method scheme lost binder visibility or its correlated Given variable"
         _ -> fail "expected one exact source provider"
   , testCase "a provider source cannot authorize a changed private scheme" $ do
       source <- goalSource identityGoal
       providers <- right $ parseProviderSexp methodProvider
       case providers of
         [ProviderFragWithContextSource name _ parts metadata] ->
           reject source [ProviderFragWithContextSource name (contextSourceFragment source) parts metadata]
         _ -> fail "expected one exact source provider"
   ])
 where
  limits = defaultSynthLimits
    { synthLimitWindow = 32, synthLimitTried = 32, synthLimitShown = 1
    , synthLimitBudget = Just 20000 }
  reject source providers = case synthesizeContextualWithProvidersSkippingDetailedWith
      False limits EngineBoth 20000 Set.empty providers source (contextSourceFragment source) of
    Left failure -> assertBool "missing explicit metadata refusal" $ "context-source:" `isInfixOf` failure
    Right _ -> assertFailure "unsupported provider acquired the identity goal's authority"

  rejectDeferred source providers = do
    let outcome = synthesizeContextualWithProvidersSkippingDetailedWith
          False limits EngineBoth 20000 Set.empty providers source (contextSourceFragment source)
        rejected failure = assertBool "duplicate owner did not fail at the source boundary" $
          "context-source:" `isInfixOf` failure
    case advanceDetailedSynthCursorWith 32 32 $ startDetailedSynthCursor outcome of
      Left failure -> assertFailure $ "cursor protocol failed before provider validation: " ++ show failure
      Right (DetailedSynthCursorEngineFailed failure) -> rejected failure
      _ -> assertFailure "duplicate foreign provider acquired a checked candidate or ordinary no-term result"

methodGoal, identityGoal, methodProvider :: String
methodGoal = "(all explicit \"a\" (given (name \"Ctx\" \"C\") 1 (args (var \"a\")) (nominal (name \"Nat\") 0 (args))))"
identityGoal = "(all explicit \"a\" (given (name \"Ctx\" \"C\") 1 (args (var \"a\")) (arrow (var \"a\") (var \"a\"))))"
methodProvider = "(providers (context-provider \"Ctx.C.out\" (name \"Ctx\" \"C\" \"out\") 1 (all implicit \"a\" (given (name \"Ctx\" \"C\") 1 (args (var \"a\")) (nominal (name \"Nat\") 0 (args))))))"

goalSource :: String -> IO ContextSource
goalSource source = do
  parsed <- right $ parseGoalSexp $
    "(goal type (query (roots \"Ctx\") (head \"Nat\")) (atom unsafe \"legacy\") (context-source 1 " ++ source ++ "))"
  case parsedGoalContextSource parsed of
    Just (Right metadata) -> pure metadata
    other -> fail $ "unsupported fixture source: " ++ show other

inspect
  :: (Ord variable, Eq local, Show local, Show absence)
  => D.TypedCandidate absence (D.Type variable) local
       (D.Candidate sourceType details (D.FunctionClause local))
  -> IO ()
inspect candidate = do
  graph <- right $ D.typedCandidateTermGraph candidate
  let clause = D.candidateOutput $ D.typedCandidateCompatibility candidate
      forms = map (D.termNodeForm . snd) $ D.termGraphNodes graph
      globals = [D.nameSpelling name | D.TypedGlobal _ name <- forms]
      applications = [witness | D.TypedContextApplication _ _ witness <- forms]
      introductions =
        [D.contextEvidenceBinder $ D.givenContextEvidence occurrence slot
        | D.TypedContextIntroduction occurrence _ witness <- forms
        , (slot, _) <- zip [0 ..] $ D.contextIntroductionConstraints witness]
  D.eraseTermGraphToFunctionClause (D.clauseName clause) graph @?= clause
  root <- maybe (fail "missing exact graph root") pure $ D.lookupTermNode (D.termGraphRoot graph) graph
  assertBool "global candidate root is open" $ Set.null $ D.freeVariables $ D.termNodeType root
  assertBool "no actual source provider used" $ not (null globals)
  assertBool "another provider or constructor entered the proof" $ all (== Just "leantProvider0") globals
  assertBool "method did not consume a lexical dictionary" $ not (null applications)
  forM_ applications $ \witness -> forM_ (D.contextApplicationEvidence witness) $ \evidence ->
    assertBool "method dictionary was donated from another scope" $
      D.contextEvidenceBinder evidence `elem` introductions

right :: Show error => Either error value -> IO value
right = either (fail . show) pure
