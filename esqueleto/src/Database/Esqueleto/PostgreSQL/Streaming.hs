{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Database.Esqueleto.PostgreSQL.Streaming
  ( selectCursor
  ) where

import Data.Text (Text)
import Data.Proxy (Proxy(..))
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Reader (ReaderT(..), ask)
import Control.Monad.Trans.Resource (MonadResource)
import Data.Conduit (ConduitT)
import Data.Conduit.Lift (runReaderC)
import Database.Esqueleto.Internal.Internal
import Database.Persist.Postgresql
import Database.Persist.Postgresql.Streaming.Internal (rawSelectStream)

-- | Execute an @esqueleto@ @SELECT@ query against a PostgreSQL backend and
-- return a stream of the results in constant memory, using the PostgreSQL
-- cursor feature.
--
-- NB: this function is likely to perform worse than 'select' on small
-- result sets.
--
-- NB: for large result sets, this function is likely to perform very poorly
-- unless you manually configure the @cursor_tuple_fraction@ setting to be
-- close to @1@. This setting decides how much PostgreSQL will prioritise
-- returning the first rows quickly vs. returning all rows efficiently. See
--
-- https://postgresqlco.nf/doc/en/param/cursor_tuple_fraction/
--
-- for more.
selectCursor
  :: forall a r m backend.
    ( SqlSelect a r
    , MonadIO m
    , MonadResource m
    , BackendCompatible (RawPostgresql SqlBackend) backend
    )
  => SqlQuery a
  -> ConduitT () r (ReaderT backend m) ()
selectCursor query = do
  backend@(RawPostgresql conn _) <- lift $ projectBackend <$> ask
  let (queryTextBuilder, vals) = toRawSql SELECT (conn, initialIdentState) query
      queryText = builderToText queryTextBuilder
  runReaderC backend
    (rawSelectStream (sqlSelectProcessRow' (Proxy :: Proxy a)) queryText vals)

#if MIN_VERSION_esqueleto(4,0,0)
sqlSelectProcessRow'
  :: (SqlSelect a result)
  => Proxy a
  -> [PersistValue]
  -> Either Text result
sqlSelectProcessRow' = sqlSelectProcessRow
#else
sqlSelectProcessRow'
  :: (SqlSelect a result)
  => Proxy a
  -> [PersistValue]
  -> Either Text result
sqlSelectProcessRow' _ = sqlSelectProcessRow
#endif

