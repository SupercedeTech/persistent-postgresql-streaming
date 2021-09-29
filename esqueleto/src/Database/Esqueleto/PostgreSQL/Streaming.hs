{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Database.Esqueleto.PostgreSQL.Streaming
  ( selectCursor
  ) where

import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.Reader (ReaderT(..), ask)
import Control.Monad.Trans.Resource (MonadResource)
import Data.Conduit
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
  ::
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
    (rawSelectStream sqlSelectProcessRow queryText vals)

