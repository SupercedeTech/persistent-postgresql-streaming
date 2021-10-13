# persistent-postgresql-streaming

This library allows for memory-constant streaming of [`persistent`](https://hackage.haskell.org/package/persistent) entities from PostgreSQL databases.

This code makes use of the PostgreSQL-only [cursors](https://www.postgresql.org/docs/current/plpgsql-cursors.html), which allow for batched access to the result set of a query at speeds comparable to loading all the results into memory at once.

See the [main project README](https://github.com/SupercedeTech/persistent-postgresql-streaming/blob/main/README.md) for more.

## Streaming Persistent queries

The main function of this library is `selectStream`, which can be used in place of [`selectSource`](https://hackage.haskell.org/package/persistent-2.13.1.2/docs/Database-Persist-Class.html#v:selectSource). `selectSource` runs in a `ConduitT` - consuming the conduit will pull results from the database in constant memory.

## FAQ

### Why is `selectStream` so slow?

Have you configured PostgreSQL correctly? See the section in the [README](https://github.com/SupercedeTech/persistent-postgresql-streaming/blob/main/README.md) about it.
