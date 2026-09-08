-- | Small opt-in display diagnostics, obtained from the exact retained
-- verification variant. These observations are not a new graph authority or
-- a kernel receipt: public acceptance still independently replays the text.
module Leant.Synth.CandidateObservation (candidateAcceptanceObservation) where

import qualified Data.Set as Set
import qualified Language.Haskell.Djex as D
import Leant.Json (JValue (..))
import Leant.Synth.Engine
import Leant.Synth.Observability (CandidateRenderingRoute (RouteTypedCandidate))

-- | The label is local to this displayed batch. Graph node and dictionary
-- occurrence identities below are local to this variant's own checked graph;
-- they are never used to associate another candidate with this observation.
candidateAcceptanceObservation :: Int -> DetailedVerificationVariant -> JValue
candidateAcceptanceObservation label variant = JObj
  [ ("schema", JInt 1)
  , ("label", JStr $ "it" ++ show label)
  , ("term", JStr $ detailedVerificationVariantText variant)
  , ("route", JStr $ show $ detailedVerificationVariantRoute variant)
  , ("variant_ordinal", JInt $ toInteger $ detailedVerificationVariantOrdinal variant)
  , ("origin", case detailedVerificationVariantRoute variant of
      RouteTypedCandidate -> maybe JNull observeOrigin $
        detailedVerificationVariantExactTypedOrigin variant
      -- A Both compatibility survivor may carry a lazy assessment-origin
      -- lookup over an unobserved opposing lane. Display diagnostics must not
      -- turn that optional recovery into search after the verification quota
      -- or deadline. Only a typed display owner is inspected here.
      _ -> JNull)
  ]
 where
  observeOrigin origin = JObj
    [ ("engine", JStr $ synthEngineName $ candidateSourceAuthorityEngine authority)
    , ("renderer_ordinal", JInt $ toInteger ordinal)
    , ("rendering", case renderExactTypedVariantOrigin origin of
        Left failure -> JObj [("failure", JStr $ show failure)]
        Right alternatives -> case drop (fromIntegral ordinal) alternatives of
          selected : _ -> JObj
            [ ("term", JStr selected)
            , ("matches_verified_text", JBool $ selected == detailedVerificationVariantText variant)
            ]
          [] -> JObj [("failure", JStr "retained renderer ordinal is absent")])
    , ("graph", foldCandidateSourceAuthority
        (observeCandidate . djinnSourceCandidate)
        (observeCandidate . typedCandidateSemanticCandidate) authority)
    ]
   where
    ordinal = exactTypedVariantOriginOrdinal origin
    authority = exactTypedVariantOriginSourceAuthority origin

observeCandidate
  :: (Ord variable, Show variable, Eq local, Show absence)
  => D.TypedCandidate absence (D.Type variable) local
       (D.Candidate sourceType details (D.FunctionClause local))
  -> JValue
observeCandidate candidate = case D.typedCandidateTermGraph candidate of
  Left absence -> JObj [("failure", JStr $ show absence)]
  Right graph -> JObj
    [ ("root", JStr $ show $ D.termGraphRoot graph)
    , ("root_type", maybe JNull (JStr . show . D.termNodeType) root)
    , ("root_closed", JBool $ maybe False (Set.null . D.freeVariables . D.termNodeType) root)
    , ("node_count", JInt $ toInteger $ length nodes)
    , ("erasure_matches_compatibility", JBool $
        D.eraseTermGraphToFunctionClause (D.clauseName clause) graph == clause)
    , ("globals", JArr [maybe JNull JStr $ D.nameSpelling name | (_, D.TypedGlobal _ name) <- forms])
    , ("context_introductions", JArr
        [ JObj [("node", JStr $ show node), ("occurrence", JStr $ show occurrence)
               , ("binders", JArr
                   [ observeEvidence $ D.givenContextEvidence occurrence slot
                   | (slot, _) <- zip [0 ..] $ D.contextIntroductionConstraints witness])]
        | (node, D.TypedContextIntroduction occurrence _ witness) <- forms])
    , ("context_applications", JArr
        [ JObj [("node", JStr $ show node), ("occurrence", JStr $ show occurrence)
               , ("evidence", JArr $ map observeEvidence $ D.contextApplicationEvidence witness)]
        | (node, D.TypedContextApplication occurrence _ witness) <- forms])
    ]
   where
    clause = D.candidateOutput $ D.typedCandidateCompatibility candidate
    root = D.lookupTermNode (D.termGraphRoot graph) graph
    nodes = D.termGraphNodes graph
    forms = [(node, D.termNodeForm value) | (node, value) <- nodes]

observeEvidence :: D.ContextEvidence -> JValue
observeEvidence evidence = JObj
  [ ("introduction", JStr $ show $ D.evidenceBinderIntroduction binder)
  , ("slot", JInt $ toInteger $ D.evidenceBinderSlot binder)
  ]
 where
  binder = D.contextEvidenceBinder evidence
