-- Standalone with -main-is BackendTraceSpec.main. To integrate into the existing
-- test runner, register backendTraceTests and dispatch runBackendTraceHelper
-- before Tasty parses its arguments. No Lean executable is used by these tests.
module BackendTraceSpec (main, backendTraceTests, runBackendTraceHelper) where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, bracket, try)
import Control.Monad (unless)
import Data.List (isInfixOf)
import System.Directory (getCurrentDirectory)
import System.Environment (getArgs, getExecutablePath)
import System.IO
  (BufferMode (..), hFlush, hGetLine, hIsEOF, hPutStr, hSetBuffering,
   hSetEncoding, stdin, stdout, utf8)
import System.Timeout (timeout)
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
  ]
 where
  startsWith (actual : _) expected = actual @?= expected
  startsWith [] _ = assertFailure "trace is empty"

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
      loop mode
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
            hPutStr stdout "{\"ok\":true}\n"
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
