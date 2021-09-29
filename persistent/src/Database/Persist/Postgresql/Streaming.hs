{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}

module Database.Persist.Postgresql.Streaming
  ( selectStream
  ) where

import Control.Monad.Reader.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.Resource
import Data.Conduit
import Data.Conduit.Lift
import Data.Foldable (toList)
import Database.Persist.Sql.Types.Internal (SqlBackend(..))
import Database.Persist.Sql.Util
import Database.Persist.Postgresql
import Database.Persist.Postgresql.Streaming.Internal

-- | Run a query against a PostgreSQL backend, streaming back the results
-- in constant memory using the PostgreSQL cursor feature.
--
-- NB: this function is likely to perform worse than 'selectSource' on small
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
selectStream
  ::
    ( MonadResource m
    , MonadReader backend m
    , PersistRecordBackend record SqlBackend
    , BackendCompatible (RawPostgresql SqlBackend) backend
    )
  => [Filter record]
  -> [SelectOpt record]
  -> ConduitT () (Entity record) m ()
selectStream filts opts = do
  backend@(RawPostgresql conn _) <- lift $ projectBackend <$> ask
  runReaderC backend $ rawSelectStream (parseEntityValues t) (sql conn) (getFiltsValues conn filts)
  where
    (limit, offset, orders) = limitOffsetOrder opts
    t = entityDef $ dummyFromFilts filts
    wher conn = filterClause Nothing conn filts
    ord conn = orderClause Nothing conn orders
    cols = commaSeparated . toList . keyAndEntityColumnNames t
    sql conn = connLimitOffset conn (limit,offset) $ mconcat
      [ "SELECT "
      , cols conn
      , " FROM "
      , connEscapeTableName conn t
      , wher conn
      , ord conn
      ]

    getFiltsValues conn = snd . filterClauseWithVals Nothing conn
    dummyFromFilts :: [Filter record] -> Maybe record
    dummyFromFilts _ = Nothing
