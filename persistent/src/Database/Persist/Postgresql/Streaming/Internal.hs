{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}

module Database.Persist.Postgresql.Streaming.Internal
  ( rawSelectStream
  ) where

import           Control.Exception (throwIO)
import           Control.Monad.IO.Class (MonadIO(liftIO))
import           Control.Monad.Logger (LoggingT(..), logDebugNS)
import           Control.Monad.Reader.Class (MonadReader(ask))
import           Control.Monad.Trans.Class (lift)
import           Control.Monad.Trans.Reader (ReaderT(..))
import           Control.Monad.Trans.Resource (MonadResource, release)
import           Data.Acquire (Acquire, allocateAcquire, mkAcquire)
import           Data.Conduit (ConduitT, (.|))
import qualified Data.Conduit.Combinators as CC (mapM, yieldMany)
import qualified Data.Text as T (Text, append, pack)
import qualified Data.Text.Encoding as T (encodeUtf8)
import           Database.Persist.Sql.Types.Internal (SqlBackend(..))
import           Database.Persist.Postgresql
import           Database.Persist.Postgresql.Internal
import qualified Database.PostgreSQL.Simple as PG
import qualified Database.PostgreSQL.Simple.Cursor as PGC
import qualified Database.PostgreSQL.Simple.Types as PG

-- | Run a @Text@ query, with interpolated @PersistValue@s, against a PostgreSQL
-- backend using cursors, parsing the results with a custom parser function and
-- streaming them back.
--
-- If the parser function returns @Left@ for any row, a 'PersistException' will
-- be thrown.
rawSelectStream
  :: MonadResource m
  => ([PersistValue] -> Either T.Text result)
  -> T.Text
  -> [PersistValue]
  -> ConduitT () result (ReaderT (RawPostgresql SqlBackend) m) ()
rawSelectStream parseRes query vals = do
  srcRes <- lift $ liftPersist $ do
    srcRes <- rawQueryResFromCursor query vals
    return $ fmap (.| CC.mapM parse) srcRes
  (releaseKey, src) <- allocateAcquire srcRes
  src
  release releaseKey
 where
  parse resVals =
    case parseRes resVals of
      Left s ->
        liftIO $ throwIO $
          PersistMarshalError ("rawSelectStream: " <> s <> ", vals: " <> T.pack (show vals ))
      Right row ->
        return row

rawQueryResFromCursor
  :: (MonadIO m1, MonadIO m2, BackendCompatible SqlBackend backend)
  => T.Text
  -> [PersistValue]
  -> ReaderT (RawPostgresql backend) m1 (Acquire (ConduitT () [PersistValue] m2 ()))
rawQueryResFromCursor sql vals = do
  RawPostgresql conn' pgConn <- ask
  let conn = projectBackend conn'
  runLoggingT
    (logDebugNS "SQL" $ T.append sql $ T.pack $ "; " ++ show vals)
    (connLogFunc conn)
  return $ withCursorStmt pgConn (PG.Query $ T.encodeUtf8 sql) vals

withCursorStmt
  :: MonadIO m
  => PG.Connection
  -> PG.Query
  -> [PersistValue]
  -> Acquire (ConduitT () [PersistValue] m ())
withCursorStmt conn query vals =
  foldWithCursor `fmap` mkAcquire openC closeC
 where
  openC = do
    rawquery <- liftIO $ PG.formatQuery conn query (map P vals)
    PGC.declareCursor conn (PG.Query rawquery)
  closeC = PGC.closeCursor
  foldWithCursor cursor = go
   where
    go = do
      -- 256 is the default chunk size used for fetching
      rows <- liftIO $ PGC.foldForward cursor 256 processRow []
      case rows of
        Left final -> CC.yieldMany final
        Right nonfinal -> CC.yieldMany nonfinal >> go
  processRow s row = pure $ s <> [map unP row]
