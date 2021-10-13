# esqueleto-streaming

This library allows for memory-constant streaming of the results of [`esqueleto`](https://hackage.haskell.org/package/esqueleto) queries from PostgreSQL databases.

This code makes use of the PostgreSQL-only [cursors](https://www.postgresql.org/docs/current/plpgsql-cursors.html), which allow for batched access to the result set of a query at speeds comparable to loading all the results into memory at once.

See the [main project README](https://github.com/SupercedeTech/persistent-postgresql-streaming/blob/main/README.md) for more.

## Streaming results from Esqueleto queries

The main function of this library is `selectCursor`, which can be used in place of [`select`](https://hackage.haskell.org/package/esqueleto-3.5.3.0/docs/Database-Esqueleto.html#v:select) to run an Esqueleto query. `selectCursor` runs in a `ConduitT` - consuming the conduit will pull results from the database in constant memory.

## FAQ

### Why is `selectCursor` so slow?

Have you configured PostgreSQL correctly? See the section in the [README](https://github.com/SupercedeTech/persistent-postgresql-streaming/blob/main/README.md) about it.
