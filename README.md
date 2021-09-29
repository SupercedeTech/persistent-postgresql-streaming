# Streaming from PostgreSQL in Persistent & Esqueleto

This collection of libraries allows for memory-constant streaming from PostgreSQL databases in a way that is compatible with the [`persistent`](https://hackage.haskell.org/package/persistent) and [`esqueleto`](https://hackage.haskell.org/package/esqueleto) libraries.

This code makes use of the PostgreSQL-only [cursors](https://www.postgresql.org/docs/current/plpgsql-cursors.html), which allow for batched access to the result set of a query at speeds comparable to loading all the results into memory at once.

## Building these libraries

At the time of writing, these libraries depend on these [two](https://github.com/yesodweb/persistent/pulls/1316) [PRs](https://github.com/yesodweb/persistent/pull/1317) to expose some useful Persistent internals. Those PRs provide as-yet-unreleased versions of `peristent` and `persistent-postgresql`, which you will need to build these streaming libraries.

The `stack.yaml` file already specifies that the project should use the unreleased versions - but if you're not using Stack, you'll have to incorporate them into your build system yourself.

## Using these libraries

### Configuring PostgreSQL

By default, cursors in PostgreSQL can be much slower than their equivalent non-cursored queries - even for very large result sets. This is because the default PostgreSQL configuration for cursors assumes that you want *only part* of the result set, and you want that part *as quickly as possible*. PostgreSQL will therefore prioritise making your cursored queries return their first-calculated results quickly - and so it won't waste time planning an efficient query.

This behaviour is controlled by the [`cursor_tuple_fraction`](https://postgresqlco.nf/doc/en/param/cursor_tuple_fraction/) config setting. By modifying the value of `cursor_tuple_fraction`, you can control how much of the result set PostgreSQL assumes you will access: high values will cause it to prioritise an efficient query plan over returning the first results quickly.

If you find that you're often accessing *all* the results in your cursored queries, the documentation advises you to set `cursor_tuple_fraction` to `0.9`. This will give cursored queries a similar or even improved performance over their equivalent non-cursored versions.

## FAQ

### What's wrong with `selectSource`?

If you've used either Persistent's or Esqueleto's `selectSource` functions, you'll know that the `ConduitT`s in their type signatures are slightly misleading - neither function actually operates in constant memory. This is a limitation of the many databases those libraries have to support; and the functions instead load all the results of a query into memory at once, leading to massive allocations and even memory starvation.

There are ways to avoid these memory blowups, such as the very helpful [`persistent-pagination`](https://hackage.haskell.org/package/persistent-pagination) library, which uses efficient pagination to batch query results. But that approach has lots of limitations (requiring a monotonic key, only streaming single tables, etc.) that mean it can't be applied to many kinds of large queries.

By using cursors, these libraries get around those limitations. It's possible to use `selectCursor` with any kind of Esqueleto `SELECT` query, and still get memory-constant streaming of the result rows: even if they don't have a monotonic key.

### Why is `selectStream`/`selectCursor` so slow?

Have you configured PostgreSQL correctly? See the section in the README about it.

