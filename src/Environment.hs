{-# LANGUAGE OverloadedStrings #-}
module Environment where

import Control.Monad.RWS (RWST, runRWST)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS
import Data.Monoid ((<>))
import Data.Trie (Trie) -- TODO: Switch to a Char-based trie.
import qualified Data.Trie as Trie

import qualified Flags


-- TASKS

type Task =
    RWST Flags.Flags () Env IO


run :: Flags.Flags -> Env -> Task a -> IO a
run flags env command =
    do  (x,_,_) <- runRWST command flags env
        return x


-- USER INPUT

data Input
    = Meta Config
    | Code (Maybe DefName, String)
    | Skip
    deriving (Show, Eq)


data Config
    = AddFlag String
    | RemoveFlag String
    | ListFlags
    | ClearFlags
      -- Just if this was triggered by an error
    | InfoFlags (Maybe String)
    | Help (Maybe String)
    | Exit
    | Reset
    deriving (Show, Eq)


data DefName
    = VarDef  String
    | DataDef String
    | Import  String
    deriving (Show, Eq)


-- ENVIRONMENT

data Env = Env
    { compilerPath  :: FilePath
    , interpreterPath :: FilePath
    , flags :: [String]
    , imports :: Trie String
    , adts :: Trie String
    , defs :: Trie String
    }
    deriving Show


empty :: FilePath -> FilePath -> Env
empty compiler interpreter =
    Env compiler
        interpreter
        []
        Trie.empty
        Trie.empty
        (Trie.singleton firstVar (BS.unpack firstVar <> " = ()"))


firstVar :: ByteString
firstVar = "tsol"


lastVar :: ByteString
lastVar = "deltron3030"


lastVarString :: String
lastVarString =
    BS.unpack lastVar


toElmCode :: Env -> String
toElmCode env =
    unlines $ "module Repl where" : decls
  where
    decls =
        concatMap Trie.elems [ imports env, adts env, defs env ]


insert :: (Maybe DefName, String) -> Env -> Env
insert (maybeName, src) env =
    case maybeName of
      Nothing ->
          display src env

      Just (Import name) ->
          noDisplay $ env
              { imports = Trie.insert (BS.pack name) src (imports env)
              }

      Just (DataDef name) ->
          noDisplay $ env
              { adts = Trie.insert (BS.pack name) src (adts env)
              }

      Just (VarDef name) ->
          define (BS.pack name) src (display name env)


define :: ByteString -> String -> Env -> Env
define name body env =
    env { defs = Trie.insert name body (defs env) }


display :: String -> Env -> Env
display body env =
    define lastVar (format body) env
  where
    format body =
        lastVarString ++ " =" ++ concatMap ("\n  "++) (lines body)


noDisplay :: Env -> Env
noDisplay env =
    env { defs = Trie.delete lastVar (defs env) }
