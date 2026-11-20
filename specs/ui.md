---
title: UI
parent: Specifications
published: false
permalink: /specs/ui/
---

# revs ui and revs tui

`revs ui` runs a local, single-user website for managing your
collection of movies and TV series and publishing it to openrevs
servers. It opens your browser
at http://localhost:1325/ (use `--no-browser` to skip that, and
`--listen` to change the address).

`revs tui` is the same thing in the terminal: the same data and
features, organized under five tabs (1 Movies & TV, 2 History, 3 Servers,
4 Identity, 5 Data). Each screen lists its keys at the bottom; esc
goes back. Both can run at once on the same data directory.

## What it does

- **Movies and TV series**: each is a movie or a TV series, with a
  title, year (for a series, the year it first aired), and optional
  Wikidata, IMDb, and TMDB IDs, with links out to those sites. A
  series's IDs are the series's own, never a season's or episode's.
  To fill in accurate details and IDs, search Wikidata from "Add a
  movie or series" or an item's edit page; results are marked as
  movies or TV series. Nothing else is fetched or stored from those
  services. The list shows both, and filters to movies or TV series
  (t in the TUI).
- **Ratings and viewings**: ratings are ½ to 5 stars. Rate a movie
  in one step: click the stars in the movie list, on a movie's page,
  or on a search result under "Add a movie" (which adds and rates it
  at once). A movie's page edits everything in place: the rating,
  each viewing's date, rating, and review, adding viewings, and
  deleting them. In the TUI,
  press r to type a rating or +/- to nudge it by half a star; adding a
  movie asks for its rating straight away. Rating an unrated movie
  records an undated viewing (a rating alone doesn't say when you
  watched it); rating it again changes the latest
  viewing's rating. A viewing also has an optional review. Most
  movies have just one, shown as "Your review". Watching it again
  adds another viewing,
  each with its own date, rating, and review; the movie list shows
  the latest, with a ×N count when there's more than one.
- **Dates**: a viewing's date is optional, and may be just a month
  (`YYYY-MM`) or a year (`YYYY`) when that's all you remember. New
  viewings start undated (the web UI has a Today button), and clearing
  the date makes a viewing undated again. History lists viewings by
  date watched, undated ones last; the web UI's "Recently added" view
  lists them by when they were added to the collection, which is how
  to find undated ones in order.
- **TV series**: a series's viewings can name a season, or a season
  and episode (season 0 is specials); with neither, a viewing is about
  the whole series. The series's rating is its latest whole-series
  viewing's: the star bar and r set that one, adding an undated one if
  there is none, and leave season and episode viewings alone. A series
  with season or episode viewings can't be changed into a movie until
  they're edited or deleted.
- **Identity**: generate an Ed25519 key, or import one (for example
  from `revs keygen`). The key signs everything you publish.
- **Servers**: add openrevs servers, push your collection to them, and
  pull everyone's published reviews from them. Pulled reviews show
  under "Others' reviews" on matching movies and series (with their
  season and episode), and per user on the server page.
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
per movie or TV series (types `movie` and `tv`), with its viewings as
entries, and a series's seasons and episodes as each entry's `season`
and `episode`. IDs go under `refs` as
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

Merging never deletes or overwrites anything. Items match only items
of the same type, by Wikidata, IMDb, or TMDB ID, otherwise by title
and year: a movie never matches a series. A viewing is added unless an
identical one (same date, rating, text, season, and episode) exists.
Items of other types are skipped.

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
