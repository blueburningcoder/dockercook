module Main where

import Cook.ArgParse
import Cook.Build
import Cook.Clean
import Cook.Types
import Cook.Uploader
import Cook.Util

import Control.Monad
import Options.Applicative
import System.Exit
import System.Log
import System.Process

runProg :: (Int, CookCmd) -> IO ()
runProg (verb, cmd) =
    do initLoggingFramework logLevel
       ec <- system "command -v docker >/dev/null 2>&1"
       case ec of
         ExitSuccess ->
             runProg' cmd
         ExitFailure _ ->
             error "dockercook requires docker. Install from http://docker.com"
    where
      logLevel =
          case verb of
            0 -> ERROR
            1 -> WARNING
            2 -> INFO
            3 -> DEBUG
            _ -> error "Invalid verbosity! Pick 0-3"

runProg' :: CookCmd -> IO ()
runProg' cmd =
    case cmd of
      CookBuild buildCfg ->
          do uploader <- mkUploader 100
             _ <- cookBuild buildCfg uploader Nothing
             when (cc_autoPush buildCfg) $
               do missingImages <- killUploader uploader
                  putStrLn $ "Waiting for " ++ (show $ length missingImages)
                               ++ " to finish beeing pushed"
                  uploadSt <- uploadImages missingImages
                  case uploadSt of
                    Left err ->
                        putStrLn $ "Failed to push all images! " ++ err
                    Right _ ->
                        putStrLn "All images pushed."
             return ()
      CookClean stateDir daysToKeep dryRun ->
          cookClean stateDir daysToKeep dryRun
      CookList ->
          do putStrLn "Available commands:"
             putStrLn "- cook"
             putStrLn "- clean"
             putStrLn "- parse"
      CookParse file ->
          cookParse file

main :: IO ()
main =
    execParser (info argParse idm) >>= runProg
