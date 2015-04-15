{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}

module Network.Bitcoin.Internal where

import Control.Applicative ((<$>), (<|>))
import           Control.Lens          ((^.))
import           Control.Monad         (mzero)
import qualified Network.Wreq          as W
import qualified Network.Wreq.Session  as WS

import Data.Maybe (fromJust)
import           Data.Aeson
import qualified Data.HashMap.Strict   as HM

import qualified Data.Text             as T
import qualified Network.Bitcoin.Types as T

data RpcResult a = RpcResultError String
                 | RpcResultOk a
  deriving (Show)

instance FromJSON a => FromJSON (RpcResult a) where
  parseJSON (Object o) =
    let checkError :: Bool
        checkError = (HM.member "error" o == True) && (HM.lookup "error" o /= (Just Null))

        parseResult hasError object
          | hasError  = RpcResultError <$> object .: "error"
          | otherwise = RpcResultOk    <$> object .: "result"

    in parseResult checkError o

call :: ( ToJSON a
        , FromJSON b
        , Show b )
     => T.Client -- ^ Our client context
     -> String   -- ^ The command we wish to execute
     -> a        -- ^ The parameters we wish to provide
     -> IO b     -- ^ The result that was returned
call client method params =
  let command = object [ "jsonrpc" .= T.pack "2.0"
                       , "method"  .= T.pack method
                       , "params"  .= params
                       , "id"      .= (1 :: Int)]

      call' = do
        r <- W.asJSON =<< WS.postWith (T.clientOpts client) (T.clientSession client) (T.clientUrl client) command
        return (r ^. W.responseBody)

  in do
    res <- call'

    case res of
     (RpcResultError err) -> fail ("An error occured: " ++ show err)
     (RpcResultOk obj) -> return obj
