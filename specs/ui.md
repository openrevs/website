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

- **Movies**: title, year, and optional Wikidata, IMDb, and TMDB IDs,
  with links out to those sites. To fill in accurate details and IDs,
  search Wikidata from "Add a movie" or a movie's edit page. Nothing
  else is fetched or stored from those services.
- **Ratings and viewings**: ratings are ½ to 5 stars. Rate a movie
  in one step: click the stars in the movie list, on a movie's page,
  or on a search result under "Add a movie" (which adds and rates it
  at once). A movie's page edits everything in place: the rating,
  each viewing's date, rating, and review, adding viewings, and
  deleting them. In the TUI,
  press r to type a rating or +/- to nudge it by half a star; adding a
  movie asks for its rating straight away. Rating an unrated movie
  records a viewing dated today; rating it again changes the latest
  viewing's rating. A viewing also has an optional review. Most
  movies have just one, shown as "Your review". Watching it again
  adds another viewing,
  each with its own date, rating, and review; the movie list shows
  the latest, with a ×N count when there's more than one.
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

Everything lives in the data directory (`--data`, default `~/.revs`),
in one SQLite database, `revs.db`: movies, viewings, settings
(including your private key), servers, your version history, and for
each server the verified corpus pulled from it, its sync state, and an
index of its reviews.

`revs.db` holds your private key, so it is created mode 0600. Pulled
documents are stored line by line, so a new revision only adds the
lines that changed, and a document published on several servers is
stored once. What is pulled from a server is a cache and can be
rebuilt by pulling again: "Discard pulled data" on a server page drops
it, keeping whatever another server also holds.

## Publishing

A push sends your whole collection as one signed document: one line
per movie, with its viewings as reviews. IDs go under `refs` as
`imdb`, `tmdb`, and `wikidata`. The client asserts the revision and
only bumps it when content has changed.

A push never silently replaces your collection on the server. If the
server holds a copy you haven't seen (pushed from another device, or
from this one before its data was wiped and your key imported again),
the push merges that copy into your collection first, pulling it if
needed, and then pushes the result. A copy you wrote, or already
merged, isn't merged again, so what you deleted locally stays deleted.

A copy the server hasn't published yet can't be merged, so that push
is reported as a conflict, and pushing again stays one until the
server's next epoch publishes it. You can wait and push again, or push
anyway and overwrite the server's copy.

Merging never deletes or overwrites anything. Movies match by
Wikidata, IMDb, or TMDB ID, otherwise by title and year. A viewing is
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
