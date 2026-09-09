-- Standalone with -main-is BackendTraceSpec.main. To integrate into the existing
-- test runner, register backendTraceTests and dispatch runBackendTraceHelper
-- before Tasty parses its arguments. No Lean executable is used by these tests.
module BackendTraceSpec (main, backendTraceTests, runBackendTraceHelper) where

import Control.Concurrent (MVar, newEmptyMVar, takeMVar, threadDelay)
import Control.Exception (SomeException, bracket, try)
import Control.Monad (replicateM_, unless)
import Data.List (isInfixOf)
import System.Directory (getCurrentDirectory)
import System.Environment (getArgs, getExecutablePath)
import System.IO
  (BufferMode (..), hFlush, hGetLine, hIsEOF, hPutStr, hSetBuffering,
   hSetEncoding, stdin, stdout, utf8)
import System.Timeout (timeout)
import System.IO.Unsafe (unsafeInterleaveIO)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase, (@?=))

import Leant.Backend
import Leant.Json

main :: IO ()
main = do
  handled <- getArgs >>= runBackendTraceHelper
  unless handled $ defaultMain backendTraceTests

backendTraceTests :: TestTree
backendTraceTests = testGroup "opt-in backend transport trace"
  [ testCase "retains exact response, request order and cleanup lifecycle" $ do
      trace <- newBackendTrace 256
      withBackend (Just trace) "echo" $ \backend -> do
        expectOk =<< request backend (Just 5) payload
        expectOk =<< request backend (Just 5) payload
      snapshot <- readBackendTrace trace
      backendTraceDroppedEvents snapshot @?= 0
      let events = backendTraceEvents snapshot
          stages identifier = [backendTraceStage event | event <- events,
                               backendTraceRequestId event == Just identifier]
          expected = [TraceRequestStarted (Just 5), TraceWriteStarted,
                      TraceWriteCompleted, TraceFlushCompleted, TraceResponseReadStarted,
                      TraceResponseFirstLine, TraceResponseDelimiter,
                      TraceResponseReadCompleted, TraceResponseParsed]
      stages 1 @?= expected
      stages 2 @?= expected
      assertBool "missing capture-thread observations" $
        TraceStdoutLineRead False `elem` map backendTraceStage events
          && TraceStdoutLineRead True `elem` map backendTraceStage events
      assertBool "cleanup was not observed" $
        TraceCleanupCompleted `elem` map backendTraceStage events
      assertBool "unexpected backend ownership" $
        all ((== 1) . backendTraceBackendId) events
      mapM_ (\identifier -> do
        let clocks = [backendTraceMonotonicNanoseconds event | event <- events,
                      backendTraceRequestId event == Just identifier]
        assertBool "one request's timestamps went backwards" $
          and $ zipWith (<=) clocks (drop 1 clocks)) [1, 2]
  , testCase "bounded trace drops old events and snapshots do not consume it" $ do
      trace <- newBackendTrace 3
      withBackend (Just trace) "echo" $ \backend ->
        expectOk =<< request backend (Just 5) payload
      first <- readBackendTrace trace
      second <- readBackendTrace trace
      first @?= second
      backendTraceCapacity first @?= 3
      length (backendTraceEvents first) @?= 3
      assertBool "event overflow was not reported" $ backendTraceDroppedEvents first > 0
      map backendTraceStage (reverse $ backendTraceEvents first)
        `startsWith` TraceCleanupCompleted
  , testCase "disabled and zero-capacity traces preserve requests" $ do
      unused <- newBackendTrace 8
      withBackend Nothing "echo" $ \backend ->
        expectOk =<< request backend (Just 5) payload
      snapshot <- readBackendTrace unused
      backendTraceEvents snapshot @?= []
      backendTraceDroppedEvents snapshot @?= 0
      zero <- newBackendTrace (-1)
      withBackend (Just zero) "echo" $ \backend ->
        expectOk =<< request backend (Just 5) payload
      bounded <- readBackendTrace zero
      backendTraceCapacity bounded @?= 0
      backendTraceEvents bounded @?= []
      assertBool "zero capacity lost its overflow evidence" $ backendTraceDroppedEvents bounded > 0
  , testCase "first response line does not end the delimiter wait" $ do
      trace <- newBackendTrace 256
      withBackend (Just trace) "echo" $ \backend -> do
        expectOk =<< request backend (Just 5) payload
        response <- request backend (Just 1) $ JObj [("cmd", JStr "split")]
        expectTimeout response
      snapshot <- readBackendTrace trace
      let stages = [backendTraceStage event | event <- backendTraceEvents snapshot,
                    backendTraceRequestId event == Just 2]
      assertBool "the valid JSON line was not received" $ TraceResponseFirstLine `elem` stages
      assertBool "missing delimiter did not retain the configured read boundary" $
        TraceRequestTimedOut `elem` stages && TraceResponseDelimiter `notElem` stages
          && TraceResponseParsed `notElem` stages
  , testCase "timeout remains a timeout and does not acquire a parsed response" $ do
      trace <- newBackendTrace 256
      withBackend (Just trace) "echo" $ \backend -> do
        expectOk =<< request backend (Just 5) payload
        response <- request backend (Just 1) $ JObj [("cmd", JStr "hang")]
        expectTimeout response
      snapshot <- readBackendTrace trace
      let stages = [backendTraceStage event | event <- backendTraceEvents snapshot,
                    backendTraceRequestId event == Just 2]
      assertBool "missing configured timeout" $ TraceRequestStarted (Just 1) `elem` stages
      assertBool "missing read timeout outcome" $ TraceRequestTimedOut `elem` stages
      assertBool "timed-out request acquired a reply" $
        TraceResponseParsed `notElem` stages && TraceResponseReadCompleted `notElem` stages
  , testCase "request deadline bounds annotation evaluation before writing" $ do
      trace <- newBackendTraceWithRequests 256
      blocked <- newEmptyMVar :: IO (MVar ())
      annotation <- unsafeInterleaveIO $ takeMVar blocked >> pure JNull
      withBackend (Just trace) "echo" $ \backend -> do
        completed <- timeout 3000000 $
          requestWithTraceAnnotation backend (Just 1) payload (Just annotation)
        case completed of
          Just response -> expectTimeout response
          Nothing -> assertFailure "annotation evaluation escaped the request deadline"
      snapshot <- readBackendTrace trace
      let stages = [backendTraceStage event | event <- backendTraceEvents snapshot,
                    backendTraceRequestId event == Just 1]
      assertBool "blocked annotation reached the protocol" $
        TraceWriteStarted `notElem` stages && TraceResponseParsed `notElem` stages
      assertBool "annotation timeout did not retain its owned request" $
        TraceRequestTimedOut `elem` stages && TraceRequestInterrupted `notElem` stages
  , testCase "request deadline bounds payload encoding without capture" $ do
      trace <- newBackendTrace 256
      blocked <- newEmptyMVar :: IO (MVar ())
      delayedPayload <- unsafeInterleaveIO $ takeMVar blocked >> pure payload
      withBackend (Just trace) "echo" $ \backend -> do
        completed <- timeout 3000000 $ request backend (Just 1) delayedPayload
        case completed of
          Just response -> expectTimeout response
          Nothing -> assertFailure "payload encoding escaped the request deadline"
      snapshot <- readBackendTrace trace
      let stages = [backendTraceStage event | event <- backendTraceEvents snapshot,
                    backendTraceRequestId event == Just 1]
      assertBool "blocked encoding reached response reading" $
        TraceResponseReadStarted `notElem` stages && TraceResponseParsed `notElem` stages
      assertBool "encoding timeout lost its request outcome" $ TraceRequestTimedOut `elem` stages
  , testCase "request deadline bounds a blocked pipe write" $ do
      trace <- newBackendTrace 256
      withBackend (Just trace) "no-read" $ \backend -> do
        completed <- timeout 3000000 $
          request backend (Just 1) (JStr $ replicate (1024 * 1024) 'x')
        case completed of
          Just response -> expectTimeout response
          Nothing -> assertFailure "pipe writing escaped the request deadline"
      snapshot <- readBackendTrace trace
      let stages = [backendTraceStage event | event <- backendTraceEvents snapshot,
                    backendTraceRequestId event == Just 1]
      assertBool "fixture failed to block before response reading" $
        TraceWriteStarted `elem` stages && TraceResponseReadStarted `notElem` stages
      assertBool "blocked write lost its timeout outcome" $ TraceRequestTimedOut `elem` stages
  , testCase "malformed JSON remains a parse failure after a complete response" $ do
      trace <- newBackendTrace 256
      withBackend (Just trace) "invalid" $ \backend -> do
        response <- request backend (Just 5) payload
        case response of
          Left (BadResponse _) -> pure ()
          other -> assertFailure $ "unexpected response: " ++ show other
      snapshot <- readBackendTrace trace
      let stages = map backendTraceStage $ backendTraceEvents snapshot
      assertBool "lost response/parse boundary" $
        TraceResponseReadCompleted `elem` stages && TraceResponseInvalidJson `elem` stages
      assertBool "invalid JSON was marked parsed" $ TraceResponseParsed `notElem` stages
  , testCase "spawn failure is observable without inventing an owned process" $ do
      executable <- getExecutablePath
      working <- getCurrentDirectory
      trace <- newBackendTrace 32
      result <- try $ spawnBackendWithTrace trace $
        BackendConfig (executable ++ ".missing-backend-trace-test") "unused" working
      case result :: Either SomeException Backend of
        Left _ -> pure ()
        Right backend -> killBackend backend >> assertFailure "nonexistent launcher started"
      snapshot <- readBackendTrace trace
      map backendTraceStage (backendTraceEvents snapshot)
        @?= [TraceSpawnStarted, TraceSpawnFailed]
  , testCase "reusing a trace distinguishes replacement backends and requests" $ do
      trace <- newBackendTrace 256
      withBackend (Just trace) "echo" $ \backend ->
        expectOk =<< request backend (Just 5) payload
      withBackend (Just trace) "echo" $ \backend ->
        expectOk =<< request backend (Just 5) payload
      snapshot <- readBackendTrace trace
      [(backendTraceBackendId event, backendTraceRequestId event) |
        event <- backendTraceEvents snapshot,
        backendTraceStage event == TraceResponseParsed] @?= [(1, Just 1), (2, Just 2)]
  , testCase "request snapshots own exact canonical payloads and replacement IDs" $ do
      trace <- newBackendTraceWithRequests 512
      let exactPayload = JObj [("cmd", JStr "unicode λ\nquoted \"value\""), ("env", JInt 7)]
          firstLabel = JObj [("role", JStr "positive-decide"), ("candidate", JStr "first")]
          secondLabel = JObj [("role", JStr "negative-decide"), ("candidate", JStr "second")]
      withBackend (Just trace) "reflect" $ \backend ->
        expectReceived exactPayload =<< requestWithTraceAnnotation backend (Just 5) exactPayload (Just firstLabel)
      withBackend (Just trace) "reflect" $ \backend ->
        expectReceived exactPayload =<< requestWithTraceAnnotation backend (Just 5) exactPayload (Just secondLabel)
      snapshot <- readBackendTrace trace
      capture <- requireCapture snapshot
      rows <- requireRows capture
      length rows @?= 2
      map (jLookup "payload_json") rows @?= replicate 2 (Just $ JStr $ encodeJson exactPayload)
      map (jLookup "annotation_json") rows
        @?= map (Just . JStr . encodeJson) [firstLabel, secondLabel]
      let payloadBytes = toInteger (length $ encodeJson exactPayload) + 1 -- λ is two UTF-8 bytes.
          annotationBytes = map (toInteger . length . encodeJson) [firstLabel, secondLabel]
      map (jLookup "payload_utf8_bytes") rows @?= replicate 2 (Just $ JInt payloadBytes)
      map (jLookup "annotation_utf8_bytes") rows @?= map (Just . JInt) annotationBytes
      jLookup "retained_bytes" capture @?= Just (JInt $ 2 * payloadBytes + sum annotationBytes)
      map (\row -> (jLookup "backend_id" row, jLookup "request_id" row)) rows
        @?= [(Just $ JInt 1, Just $ JInt 1), (Just $ JInt 2, Just $ JInt 2)]
      jLookup "omitted_records" capture @?= Just (JInt 0)
      mapM_ (\row -> do
        let identifier = jLookup "request_id" row >>= jInt
            stages = [(backendTraceStage event, toInteger $ backendTraceMonotonicNanoseconds event)
                     | event <- backendTraceEvents snapshot, backendTraceRequestId event == identifier]
        case (lookup (TraceRequestStarted $ Just 5) stages,
              jLookup "capture_started_ns" row >>= jInt,
              jLookup "capture_completed_ns" row >>= jInt,
              lookup TraceWriteStarted stages) of
          (Just start, Just captureStart, Just captureEnd, Just writeStart) ->
            assertBool "capture clocks escaped the request/send boundary" $
              start <= captureStart && captureStart <= captureEnd && captureEnd <= writeStart
          other -> assertFailure $ "missing correlation clocks: " ++ show other) rows
      -- Exercise full serialization, not just a lazy snapshot constructor.
      parseJson (encodeJson capture) @?= Right capture
  , testCase "disabled request capture never demands an annotation" $ do
      withBackend Nothing "echo" $ \backend ->
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload
          (error "disabled tracing evaluated metadata")
      trace <- newBackendTrace 256
      withBackend (Just trace) "echo" $ \backend ->
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload
          (Just $ error "event-only tracing evaluated metadata")
      snapshot <- readBackendTrace trace
      backendTraceRequestCapture snapshot @?= Nothing
      assertBool "event-only tracing stopped observing requests" $
        TraceResponseParsed `elem` map backendTraceStage (backendTraceEvents snapshot)
  , testCase "oversized or unrepresentable UTF-8 omits the whole row only" $ do
      trace <- newBackendTraceWithRequests 256
      withBackend (Just trace) "echo" $ \backend -> do
        -- Under the character limit but over the UTF-8 byte limit.
        expectOk =<< requestWithTraceAnnotation backend (Just 5)
          (JObj [("cmd", JStr $ replicate 90000 '界')])
          (Just $ error "oversized payload evaluated its unnecessary annotation")
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload
          (Just $ JStr $ replicate 8192 'x')
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload
          (Just $ JStr ['\xD800'])
        expectOk =<< request backend (Just 5) payload
      capture <- readBackendTrace trace >>= requireCapture
      rows <- requireRows capture
      length rows @?= 1
      map (jLookup "request_id") rows @?= [Just $ JInt 4]
      map (jLookup "annotation_json") rows @?= [Just JNull]
      map (jLookup "payload_json") rows @?= [Just $ JStr $ encodeJson payload]
      jLookup "omitted_records" capture @?= Just (JInt 3)
      (jLookup "omissions" capture >>= jLookup "payload_byte_limit") @?= Just (JInt 1)
      (jLookup "omissions" capture >>= jLookup "annotation_byte_limit") @?= Just (JInt 1)
      (jLookup "omissions" capture >>= jLookup "invalid_unicode") @?= Just (JInt 1)
  , testCase "full row capacity preserves requests without demanding omitted metadata" $ do
      trace <- newBackendTraceWithRequests 0
      withBackend (Just trace) "echo" $ \backend -> do
        replicateM_ 128 $ expectOk =<< request backend (Just 5) payload
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload
          (error "row-full capture evaluated metadata")
      snapshot <- readBackendTrace trace
      backendTraceEvents snapshot @?= []
      capture <- requireCapture snapshot
      rows <- requireRows capture
      length rows @?= 128
      map (jLookup "request_id") rows @?= map (Just . JInt) [1 .. 128]
      jLookup "retained_bytes" capture @?= Just (JInt $ 128 * toInteger (length $ encodeJson payload))
      jLookup "omitted_records" capture @?= Just (JInt 1)
      (jLookup "omissions" capture >>= jLookup "row_limit") @?= Just (JInt 1)
      second <- readBackendTrace trace >>= requireCapture
      capture @?= second
  , testCase "explicit request limit retains later owners without changing requests" $ do
      trace <- newBackendTraceWithRequestLimit 130 0
      withBackend (Just trace) "reflect" $ \backend -> do
        replicateM_ 130 $ expectReceived payload =<< request backend (Just 5) payload
        expectReceived payload =<< requestWithTraceAnnotation backend (Just 5) payload
          (error "selected row-full capture evaluated metadata")
      capture <- readBackendTrace trace >>= requireCapture
      rows <- requireRows capture
      jLookup "row_limit" capture @?= Just (JInt 130)
      map (jLookup "request_id") rows @?= map (Just . JInt) [1 .. 130]
      jLookup "omitted_records" capture @?= Just (JInt 1)
      jLookup "total_byte_limit" capture @?= Just (JInt $ 4 * 1024 * 1024)
  , testCase "request limit clamps excessive and negative diagnostic settings" $ do
      large <- newBackendTraceWithRequestLimit 100000 0 >>= readBackendTrace >>= requireCapture
      jLookup "row_limit" large @?= Just (JInt 1024)
      zero <- newBackendTraceWithRequestLimit (-1) 0
      withBackend (Just zero) "reflect" $ \backend ->
        expectReceived payload =<< requestWithTraceAnnotation backend (Just 5) payload
          (error "zero-row capture evaluated metadata")
      empty <- readBackendTrace zero >>= requireCapture
      jLookup "row_limit" empty @?= Just (JInt 0)
      jLookup "requests" empty @?= Just (JArr [])
      jLookup "omitted_records" empty @?= Just (JInt 1)
  , testCase "aggregate capture bound admits whole exact-size payloads only" $ do
      trace <- newBackendTraceWithRequests 0
      let exactSizePayload = JStr $ replicate (256 * 1024 - 2) 'x'
      withBackend (Just trace) "echo" $ \backend -> do
        replicateM_ 16 $ expectOk =<< request backend (Just 5) exactSizePayload
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload
          (error "byte-full capture evaluated metadata")
      capture <- readBackendTrace trace >>= requireCapture
      rows <- requireRows capture
      length rows @?= 16
      map (jLookup "payload_utf8_bytes") rows @?= replicate 16 (Just $ JInt $ 256 * 1024)
      map (jLookup "payload_json") rows @?= replicate 16 (Just $ JStr $ encodeJson exactSizePayload)
      jLookup "retained_bytes" capture @?= Just (JInt $ 4 * 1024 * 1024)
      jLookup "omitted_records" capture @?= Just (JInt 1)
      (jLookup "omissions" capture >>= jLookup "total_byte_limit") @?= Just (JInt 1)
  , testCase "late output cannot donate a timed-out request's label to replacement" $ do
      trace <- newBackendTraceWithRequests 512
      let failedLabel = JObj [("role", JStr "negative-decide"), ("candidate", JStr "failed")]
          nextLabel = JObj [("role", JStr "positive-simp"), ("candidate", JStr "next")]
      withBackend (Just trace) "late" $ \backend -> do
        expectTimeout =<< requestWithTraceAnnotation backend (Just 1) payload (Just failedLabel)
        arrived <- timeout 3000000 $ waitForLateLine trace
        arrived @?= Just ()
      withBackend (Just trace) "echo" $ \backend -> do
        -- Startup/replay remains unlabelled; no failed callback context is inherited.
        expectOk =<< request backend (Just 5) payload
        expectOk =<< requestWithTraceAnnotation backend (Just 5) payload (Just nextLabel)
      snapshot <- readBackendTrace trace
      capture <- requireCapture snapshot
      rows <- requireRows capture
      map (\row -> (jLookup "backend_id" row, jLookup "request_id" row)) rows
        @?= [(Just $ JInt 1, Just $ JInt 1), (Just $ JInt 2, Just $ JInt 2),
             (Just $ JInt 2, Just $ JInt 3)]
      map (jLookup "annotation_json") rows
        @?= [Just $ JStr $ encodeJson failedLabel, Just JNull, Just $ JStr $ encodeJson nextLabel]
      let events = backendTraceEvents snapshot
          timedOut = [backendTraceMonotonicNanoseconds event | event <- events,
            backendTraceBackendId event == 1, backendTraceRequestId event == Just 1,
            backendTraceStage event == TraceRequestTimedOut]
          late = [backendTraceMonotonicNanoseconds event | event <- events,
            backendTraceBackendId event == 1, backendTraceStage event == TraceStdoutLineRead False]
      assertBool "late output was not actually later than the request timeout" $
        case (timedOut, late) of ([ended], first : _) -> ended < first; _ -> False
      assertBool "capture output acquired a guessed request owner" $ all
        ((== Nothing) . backendTraceRequestId)
        [event | event <- events, backendTraceStage event == TraceStdoutLineRead False]
      assertBool "the timed-out request acquired a parsed response" $ null
        [event | event <- events, backendTraceRequestId event == Just 1,
         backendTraceStage event == TraceResponseParsed]
  ]
 where
  startsWith (actual : _) expected = actual @?= expected
  startsWith [] _ = assertFailure "trace is empty"

expectReceived :: JValue -> Either RequestError JValue -> Assertion
expectReceived sent response = case response of
  Right value -> value @?= JObj [("received", JStr $ encodeJson sent ++ "\n")]
  Left failure -> assertFailure $ "unexpected reflecting transport failure: " ++ show failure

requireCapture :: BackendTraceSnapshot -> IO JValue
requireCapture snapshot = case backendTraceRequestCapture snapshot of
  Just capture -> pure capture
  Nothing -> assertFailure "explicit request capture is absent" >> pure JNull

requireRows :: JValue -> IO [JValue]
requireRows capture = case jLookup "requests" capture >>= jArray of
  Just rows -> pure rows
  Nothing -> assertFailure "request capture has no row array" >> pure []

waitForLateLine :: BackendTrace -> IO ()
waitForLateLine trace = do
  snapshot <- readBackendTrace trace
  if any ((== TraceStdoutLineRead False) . backendTraceStage) (backendTraceEvents snapshot)
    then pure ()
    else threadDelay 1000 >> waitForLateLine trace

payload :: JValue
payload = JObj [("cmd", JStr "payload must not be logged")]

expectOk :: Either RequestError JValue -> Assertion
expectOk response = case response of
  Right value -> value @?= JObj [("ok", JBool True)]
  Left failure -> assertFailure $ "unexpected transport failure: " ++ show failure

expectTimeout :: Either RequestError JValue -> Assertion
expectTimeout (Left RequestTimeout) = pure ()
expectTimeout other = assertFailure $ "expected response timeout, received " ++ show other

withBackend :: Maybe BackendTrace -> String -> (Backend -> IO a) -> IO a
withBackend trace mode action = do
  executable <- getExecutablePath
  working <- getCurrentDirectory
  let config = BackendConfig executable ("--backend-trace-helper=" ++ mode) working
      spawn = maybe spawnBackend spawnBackendWithTrace trace config
      cleanup backend = do
        stopped <- timeout 4000000 $ killBackend backend
        case stopped of
          Just () -> pure ()
          Nothing -> assertFailure "fake backend cleanup exceeded its bound"
  bracket spawn cleanup action

runBackendTraceHelper :: [String] -> IO Bool
runBackendTraceHelper ["env", argument]
  | Just mode <- strip "--backend-trace-helper=" argument = do
      hSetEncoding stdin utf8
      hSetEncoding stdout utf8
      hSetBuffering stdout NoBuffering
      if mode == "no-read" then threadDelay 10000000 else loop mode
      pure True
 where
  loop mode = do
    ended <- hIsEOF stdin
    unless ended $ do
      message <- readMessage []
      if "hang" `isInfixOf` message
        then threadDelay 10000000
        else if mode == "invalid"
          then hPutStr stdout "{bad}\n\n" >> hFlush stdout
          else do
            if mode == "late" then threadDelay 1250000 else pure ()
            hPutStr stdout $ (if mode == "reflect"
              then encodeJson $ JObj [("received", JStr message)]
              else "{\"ok\":true}") ++ "\n"
            hFlush stdout
            if "split" `isInfixOf` message then threadDelay 10000000 else pure ()
            hPutStr stdout "\n"
            hFlush stdout
      loop mode
  readMessage acc = do
    line <- hGetLine stdin
    if null line then pure (unlines $ reverse acc) else readMessage (line : acc)
runBackendTraceHelper _ = pure False

strip :: String -> String -> Maybe String
strip [] rest = Just rest
strip (x : xs) (y : ys) | x == y = strip xs ys
strip _ _ = Nothing
