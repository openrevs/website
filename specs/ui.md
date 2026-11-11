---
title: UI
parent: Specifications
published: false
permalink: /specs/ui/
---

# revs ui and revs tui

`revs ui` runs a local, single-user website for managing your movie
collection and publishing it to openrevs servers. It opens your browser
at http://localhost:1325/ (use `--no-browser` to skip that, and
`--listen` to change the address).

`revs tui` is the same thing in the terminal: the same data and
features, organized under five tabs (1 Movies, 2 History, 3 Servers,
4 Identity, 5 Data). Each screen lists its keys at the bottom; esc
goes back. Both can run at once on the same data directory.

## What it does

- **Movies**: title, year, and optional Wikidata, IMDb, and TMDB ids,
  with links out to those sites. To fill in accurate details and ids,
  search Wikidata from "Add a movie" or a movie's edit page. Nothing
  else is fetched or stored from those services.
- **Viewings**: each movie has any number of viewings, each with a
  date, an optional 0–5 star rating, and an optional review.
- **Identity**: generate an Ed25519 key, or import one (for example
  from `revs keygen`). The key signs everything you publish.
- **Servers**: add openrevs servers, push your collection to them, and
  pull everyone's published reviews from them. Pulled reviews show
  under "Others' reviews" on matching movies, and per user on the
  server page.
- **Import/Export**: save your collection as a signed sjsonl
  ratingset, or merge in a ratingset file (signed, or unsigned JSON
  lines).

## Data

Everything lives in the data directory (`--data`, default `~/.revs`):

    revs.db           movies, viewings, settings (including your private key), servers
    servers/<id>.db   one per server: the verified corpus pulled from it,
                      sync state, and an index of its reviews

`revs.db` holds your private key, so it is created mode 0600. The
per-server databases are caches and can be rebuilt by pulling again.
"Discard pulled data" on a server page deletes its file.

## Publishing

A push sends your whole collection as one signed document: one line
per movie, with its viewings as reviews. Ids go under `refs` as
`imdb`, `tmdb`, and `wikidata`. The client asserts the revision and
only bumps it when content has changed. If another device pushed with
the same key in the meantime, the push is reported as a conflict. You
can then pull, merge the server's copy into your collection, and push
again, or push anyway and overwrite the server's copy.

Merging never deletes or overwrites anything. Movies match by
Wikidata, IMDb, or TMDB id, otherwise by title and year. A viewing is
added unless an identical one (same date, rating, and text) exists.

## Security

The UI is for one person on their own machine. When it listens on a
loopback address, it only answers requests whose `Host` is localhost,
which blocks DNS rebinding. Cross-origin form posts are always
refused. There is no login, so don't expose it on a shared network.

## Development

Both front ends are thin layers over the `collection` package, which
owns the databases, validation, search, import/export, and
publishing. Queries live in `collection/queries` and
`collection/remotequeries`. Schemas are goose migrations in
`collection/migrations` and `collection/remotemigrations`, embedded
and applied at startup. Regenerate the Go code with `make generate`
(sqlc v1.30.0).
