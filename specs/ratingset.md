---
title: Ratingset
parent: Specifications
published: false
permalink: /specs/ratingset/
---

# Ratingset Specification

A **ratingset** is one person's ratings and reviews, published as a single
[SJSONL](/specs/sjsonl/) document. It is meant to be a standalone document that
capture the author identity and all of the items and their ratings.

### Structure

A ratingset contains:

- one **author line**, which identifies the author and declares their rating
  scale
- one **item line** for each movie (or other item) they've logged. An item line
  holds all of the author's **entries** for that item. An entry records one
  occasion, such as one viewing, with an optional date, rating, and review.

### Item identification
The items in the file are meant to be sufficiently self-descriptive such that
referencing an external database isn't required. For example, items include a
movie name and optionally year of release, and are thus human readable. But
additional identifiers, such an an IMDb ID, may also be included to help
consumers unamgiuously correlate items.

## Example

```
{"sjsonl":"1","key":"…","sig":"…"}
{"id":"601b27ee…","max_rating":10,"min_rating":0,"next":"9c4e1a07…","revision":4}
{"entries":[{"date":"1997-07-07","rating":9,"review":"Great"},{"date":"2020-01-01","rating":8}],"refs":{"imdb":"tt0110912","tmdb":"680","wikidata":"Q104123"},"title":"Pulp Fiction","type":"movie","year":1994}
{"entries":[{"rating":7}],"title":"Rocky","type":"movie","year":1976}
{"entries":[{"date":"2015-03-01","rating":9,"season":1},{"date":"2016-04-10","rating":6,"season":2},{"date":"2019-06-02","rating":8,"review":"Uneven, but the highs are very high."}],"refs":{"imdb":"tt2802850","tmdb":"60622","wikidata":"Q15931555"},"title":"Fargo","type":"tv","year":2014}
```

The first line is the SJSONL header, defined by the SJSONL spec. The
data lines follow.

## Document

A ratingset MUST be a valid, signed SJSONL document. Its data lines
consist of:

- exactly one author line, and
- zero or more item lines.

The author line and item lines may appear in any order. Consumers MUST
NOT rely on the author line being first. Generators SHOULD put it
first.

**How lines are told apart:** a data line that has an `id` member is
the author line; every other data line is an item line. An item line
therefore MUST NOT have an `id` member. A document with more than one
line carrying `id` is invalid.

Every data line MUST be a JSON object.

## Privacy

A ratingset identifies its author only by a key-derived ID. It carries
no real-world identity: no name, email address, or other contact
details. Linking an ID to a person, if anyone wants that, is left to
other applications.

Generators MUST NOT add identifying fields to the author line, even
though the [unknown fields](#unknown-fields) rule would let them.

## Author line

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `id` | string | yes | The author's ID (see below). |
| `revision` | integer ≥ 1 | yes | The document's revision number. |
| `min_rating` | integer | yes | Lowest value on the rating scale. |
| `max_rating` | integer | yes | Highest value on the rating scale. |
| `next` | string | no | The author ID of the successor key (see [Key status](#key-status)). |
| `previous` | string | no | The author ID this author succeeds. |
| `status` | string | no | `"retired"` or `"moved"`. Absent means active. |

### Author ID

The author ID is the SHA-256 hash of the 32-byte Ed25519 public key
that signed the document, written as 64 lowercase hex characters. A
ratingset whose `id` doesn't match its signing key is invalid. That
rule binds a document to its author: only the key holder can publish
under that ID.

### Revision

`revision` orders an author's documents. Each new document from an
author MUST have a higher `revision` than every earlier one. Revisions
don't need to be consecutive, but clients SHOULD use the next number
after the author's latest revision.

Servers reject a document whose `revision` is missing or less than 1,
or not greater than the latest one they've accepted for that author.
`revision` MUST be an integer from 1 to 2147483647 (2³¹ − 1), so it
fits in a signed 32-bit integer. Servers and consumers MUST reject a
document whose `revision` is outside that range, and MUST check this
before any other check. An out-of-range value MUST NOT be wrapped,
truncated, or rounded into range.

Clients SHOULD assign a new revision only when content has changed.
`revision` is the only field that changes when nothing else does, which
is why it lives on the author line and not on item lines.

### Revision ceiling

The **revision ceiling** is the number of seconds since the revision
epoch, 2026-01-01T00:00:00Z (Unix time 1767225600), plus 60:

```
ceiling = unix_time_seconds - 1767225600 + 60
```

Servers reject a document whose `revision` is greater than the
ceiling. The epoch is fixed and never changes.

Without a ceiling, anyone who can sign for an author (a thief, or a
rogue delegate) could publish the largest possible revision and leave
the author no higher number to use, freezing the document for good.
With the ceiling, the highest revision anyone can reach is about "now".
The author waits out the 60-second allowance and publishes above it.

The ceiling doesn't affect normal use. Revisions that count up from 1
stay far below it: the ceiling grows by about 31.5 million a year.
Clients that want time-based revisions can use seconds since the
revision epoch, as long as they publish at most one revision per
second.

Counting from 2026 keeps the ceiling within the 32-bit range of
`revision` until 2094.

The ceiling applies only when a document is accepted. Time only moves
forward, so a revision that was under the ceiling when a server
accepted it stays under it. Mirrors and consumers that receive the
document later don't need to check it again. Servers need reasonably
accurate clocks: a server whose clock runs far ahead would accept
revisions that other servers reject.

## Key status

An author ID is bound to one key. This section covers what happens when
an author stops using that key, either by choice or because the key is
lost or stolen.

There are two cases:

- **Retirement.** The author is done. The current key closes the ID,
  and nothing more is published under it.
- **Rotation.** The author moves to a new key, and so to a new author
  ID. Consumers can verify the link between the two IDs.

Rotation works only if the author prepared for it in advance. A stolen
key can sign anything the real author can, so once a key leaks it
can't vouch for its own replacement. An author who didn't prepare can
only retire.

### Next key

`next` commits to the author's successor key ahead of time. Its value
is the author ID of a second keypair, written the same way as `id`.
Because an ID is the hash of a public key, `next` reveals nothing about
the successor key itself.

- `next` MUST be 64 lowercase hex characters and MUST NOT equal `id`.
- `next` may first appear in any revision. Once a server has accepted
  a revision with `next`, every later revision MUST carry the same
  `next`. A revision that changes or drops it is rejected.

Because `next` can't change, someone who steals the current key can't
redirect the succession to a key of their own. They could only do that
by setting `next` first, which is why clients SHOULD set `next` in the
author's first revision.

Clients SHOULD generate the successor keypair when they create the
author's key, and SHOULD keep the successor's private key offline
(printed or in a separate backup), not next to the current key. A
successor key stored with the current key is lost or stolen along with
it.

### Status

`status` records that an ID is closed:

| Value | Meaning |
|-------|---------|
| absent | Active. |
| `retired` | The author has stopped publishing under this ID. |
| `moved` | The author has moved to the ID in `next`. |

- `moved` requires `next`.
- Both values close the ID. After a `moved` revision, servers reject
  any later revision of that ID. After a `retired` revision, servers
  accept only a `moved` revision, and reject everything else.
- A document whose `status` has any other value is invalid. `status`
  controls whether an ID is still open, so consumers can't safely
  ignore a value they don't know.

A `retired` or `moved` revision still holds whatever item lines the
author leaves in it. Closing an ID stops new revisions. It doesn't
invalidate earlier ones.

Someone who steals a key can retire the ID, but they can't reopen a
retired ID and keep publishing. Even an author who didn't prepare can
use this to cut off a thief, at the cost of the ID.

`moved` is allowed after `retired` so that a thief can't block a move
by retiring the ID first. This is safe because `next` can't change: a
`moved` revision can only point to the successor the author committed
to, so it doesn't matter who signs it.

### Rotation

The successor key performs a rotation by publishing a ratingset whose
`id` is the predecessor's `next` and whose `previous` is the
predecessor's `id`. The successor's document carries the author's
ratings from then on.

- `previous`, when set, MUST stay the same in every later revision of
  the successor's ID.
- The link is valid only if the predecessor's accepted `next` equals
  the successor's `id`. A `previous` that doesn't check out is
  meaningless, and consumers MUST NOT treat it as a link.
- Once a valid successor document is accepted, the predecessor ID is
  closed, the same as after a `moved` revision. This works whether or
  not the predecessor was already retired or marked `moved`. A thief
  who retires an ID can't block the successor.

The old key isn't needed to rotate, so rotation works for lost keys as
well as stolen ones. When the old key is still available, the author
SHOULD first publish a final `moved` revision under it. Consumers who
only have the old ID then learn about the move without searching for
the successor's document.

The successor's document SHOULD carry its own `next`, so that it can
be rotated in turn.

### Following a rotation

A consumer that sees `status: moved` SHOULD look for the successor's
documents under the ID in `next`. A consumer that sees `previous`
SHOULD check the predecessor's `next` before treating the two IDs as
one author. Whether to merge an author's history across IDs, and how
to present it, is up to the consumer.

## Ratings

### Rating scale

`min_rating` and `max_rating` declare the scale that every `rating` in
the document uses. The scale is the inclusive range of integers
`min_rating`..`max_rating`. `max_rating` MUST be greater than
`min_rating`. An author line without a valid scale is invalid.

Ratings are integers, so a scale with fractional steps is written as a
scaled-up integer range. Half stars are the common case: five stars in
half-star steps is `min_rating` 0, `max_rating` 10, and 3½ stars is
written as `7`. How to display ratings, as stars, out of 10, or as
anything else, is up to the client.

### Reading ratings across documents

Different authors and clients may use different scales. A consumer
MUST read each document's ratings against that document's own scale,
never against a fixed one. To compare or display ratings from several
documents, convert them proportionally:

```
fraction = (rating - min_rating) / (max_rating - min_rating)
```

then map `fraction` onto the consumer's own scale.

### Notes for generators

- Declare the scale your ratings actually use, and keep it the same
  across an author's documents where you can. Changing the scale
  changes every item line, so the next revision rewrites the whole
  document.
- Pick a scale whose steps match what users can enter. A 0–10 scale
  for half stars converts exactly. A scale that's too coarse loses
  precision for everyone who reads the document.

## Item line

An item line describes one item and holds the author's entries for it.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `type` | string | yes | The kind of item, e.g. `"movie"`. |
| `title` | string | yes | The item's title. |
| `year` | integer | no | Year of release. For `tv`, the year the series first aired. |
| `refs` | object of string → string | no | IDs of the item in other catalogs. |
| `entries` | array of entry objects | no | The author's entries for the item. |

`title` MUST be non-empty after trimming whitespace.

An item line that breaks any rule in this section or in
[Entry](#entry) is invalid. Consumers skip invalid item lines and
still use the rest of the document (see [Validation](#validation)).

### Type

`type` says what kind of thing the item is. The rest of the item line
depends on it: which `refs` keys apply, what `year` means, and which
entry fields apply. The values defined so far are:

| Value | Item |
|-------|------|
| `movie` | A film, including a TV movie. |
| `tv` | A TV series, as a whole. See [TV series](#tv-series). |

Consumers compare `type` without regard to case, and skip items whose
type they don't support.

`type` is required so that new kinds of item (books, games)
can be added later without making existing documents ambiguous.

### Refs

`refs` maps a catalog name to the item's ID in that catalog. It lets
consumers match the same item across documents more reliably than
title and year alone. Defined keys for `movie`:

| Key | Value | Example |
|-----|-------|---------|
| `imdb` | IMDb title ID | `tt0110912` |
| `wikidata` | Wikidata item ID | `Q104123` |
| `tmdb` | TMDB movie ID (numeric) | `680` |

Defined keys for `tv`, all naming the series as a whole:

| Key | Value | Example |
|-----|-------|---------|
| `imdb` | IMDb title ID of the series | `tt2802850` |
| `wikidata` | Wikidata item ID of the series | `Q15931555` |
| `tmdb` | TMDB TV series ID (numeric) | `60622` |

A `tv` item's refs MUST name the series, never one of its seasons or
episodes. IMDb gives episodes their own title IDs and Wikidata often
has items for seasons, but those belong to the parts of the series,
which entries identify by number instead (see [TV series](#tv-series)).

Generators SHOULD emit keys in lowercase and values in the forms shown,
and SHOULD include `imdb` when it's known. Consumers match keys without
regard to case, and SHOULD accept common variants of the values: a URL,
a TMDB slug such as `680-pulp-fiction`, or a lowercase Wikidata `q`.
Consumers ignore keys they don't know.

A ref's meaning depends on the item's `type`. TMDB numbers movies and
TV series separately, so the same number can name two different items.
For a `movie` item, `tmdb` is always a movie ID, and for a `tv` item
it is always a TV series ID. Consumers MUST
interpret refs according to the item's `type`, and MUST NOT match refs
across items of different types.

Generators SHOULD omit `refs` when it would be empty.

### Matching items

Consumers that merge items from several documents need to decide when
two item lines describe the same item. The rule for refs:

- Two items of the same `type` **match** when they have at least one
  ref key in common and the values agree for **every** key they have in
  common.
- They **conflict** when any key they have in common has a different
  value. A conflict means one of the documents has a wrong ID.

Since every key they share has to agree, the order the keys are
checked in doesn't change the result. Consumers that need one key per
item (for an index, say) SHOULD prefer them in this order: `imdb`,
`wikidata`, `tmdb`. That puts the most commonly available ID first.

How to handle conflicting items (keep them apart, or pick one key to
trust), and how to match items that have no refs in common (by title
and year, by fuzzy matching, or not at all), are up to the consumer.
Keeping conflicting items apart is the safe default, because merging
them on a wrong ID pulls the wrong entries into an item.

## Entry

An entry is one occasion of the author engaging with an item, such as
one viewing of a movie.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `date` | string `YYYY-MM-DD`, `YYYY-MM`, or `YYYY` | no | When it happened, to the day, month, or year. |
| `rating` | integer | no | The rating, on the document's scale. |
| `review` | string | no | The author's written review. |
| `season` | integer ≥ 0 | no | `tv` only: the season the entry is about. |
| `episode` | integer ≥ 1 | no | `tv` only: the episode, within `season`, the entry is about. |

All fields are optional, so an entry can be a bare record that a
viewing happened.

- An entry without `rating` is **unrated**, which is different from a
  rating of `min_rating`.
- A `rating`, if present, MUST be within the declared scale. An item
  line containing an out-of-range rating is invalid.
- A `date`, if present, MUST be a valid calendar date in `YYYY-MM-DD`
  form, or, when the author doesn't know the day, a valid month in
  `YYYY-MM` form or a year in `YYYY` form. An item line containing any
  other date is invalid. A partial date means some time within that
  month or year; it isn't the first of it. Generators MUST NOT invent
  precision they don't have (such as writing `2019-05-01` for "May
  2019"), and SHOULD leave `date` out rather than guess one (such as
  the day a rating was recorded) when nothing says when it happened.
- Dates in these forms compare correctly as strings: a partial date
  sorts just before the more precise dates within it (`2019` <
  `2019-05` < `2019-05-04`).
- `season` and `episode` are defined only for `tv` items. Generators
  MUST NOT put them on entries of any other type. An entry with
  `episode` MUST also have `season`. An item line breaking either rule,
  or with a `season` or `episode` that isn't an integer in range, is
  invalid.
- The order of entries carries no meaning. Consumers sort entries by
  `date` themselves when they need an order. Generators order entries
  as described in [Line structure](#line-structure), which
  keeps the line's bytes the same from revision to revision.

### Reviews

`review` is plain text. Line breaks are written as `\n`. Consumers
MUST NOT interpret a review as HTML or any other markup. To display a
review, render it as text.

This spec sets no length limit on reviews. A review is limited only by
the document's size. Consumers MAY truncate long reviews for display.

## TV series

A TV series is one item: one `tv` item line per series, holding every
entry the author has for it. Seasons and episodes aren't items of
their own. They have no stable IDs that work across catalogs (TMDB
identifies a season only as a series ID plus a season number, and
IMDb has no season IDs at all), while every catalog has an ID for the
series. Keeping the series as the item means refs and
[matching](#matching-items) work exactly as they do for movies.

An entry says which part of the series it's about:

| Entry has | It's about |
|-----------|------------|
| neither `season` nor `episode` | The series as a whole. |
| `season` | That season. |
| `season` and `episode` | That episode of that season. |

Seasons and episodes are numbered as the catalogs number them, usually
from 1. Season `0` holds specials, following TMDB and TheTVDB.
Consumers that need to show a season or episode title look it up in a
catalog using the series ref and the numbers.

### Multiple viewings

Each entry is still one occasion. Watching a season twice is two
entries with the same `season`, each with its own date, rating, and
review. A series-level entry is the author's view of the series as a
whole, written whenever they like, and doesn't need a matching set of
season entries. An author who rates only seasons, only the series, or
a mix of both is writing a valid item.

### Miniseries and specials

Use the catalogs' classification: if IMDb or TMDB lists something as a
TV series (including a miniseries or limited series), it's a `tv`
item. A TV movie is a `movie` item, even when it belongs to a series.

## Unknown fields

Consumers MUST ignore fields they don't recognize on the author line,
item lines, and entries. Future versions of this spec and application
extensions may add fields.

## Line encoding

All of the SJSONL [line encoding
recommendations](/specs/sjsonl/#line-encoding-recommendations) apply
to a ratingset. This section narrows them, so that independent
generators encoding the same data produce the same bytes.

As in SJSONL, these rules are for generators only. Servers and
consumers MUST accept any line that is valid under this spec, and MUST
NOT re-encode lines before hashing, storing, or republishing them.

### Encoding rules

Generators SHOULD encode every line as follows:

- **Compact form**, with no insignificant whitespace.
- **Object keys sorted lexicographically** at every nesting level: on
  the author line, item lines, entries, and `refs`. This is the SJSONL
  default, needs no per-field table, and any JSON library can produce
  it.
- **Absent optional fields omitted**, not written as `null`, `""`,
  `[]`, or `{}`.
- **Strings in UTF-8, escaping only what JSON requires.** Don't escape
  `<`, `>`, `&`, or non-ASCII characters. In Go, this means a
  `json.Encoder` with `SetEscapeHTML(false)` (stripping the trailing
  newline it adds) rather than `json.Marshal`.
- **Strings Unicode NFC-normalized.** This matters most for `title`:
  `Amélie` typed with a precomposed `é` and with `e` plus a combining
  accent are different bytes, and so different lines.
- **Dates** as `YYYY-MM-DD`, `YYYY-MM`, or `YYYY`, with zero-padded
  months and days, and no more precise than what is known.
- **Numbers** as plain decimal integers.

### Field order

All keys are ASCII, so lexicographic order is plain byte order. For
the fields defined today:

| Line | Fields, in order |
|------|------------------|
| Author line | `id`, `max_rating`, `min_rating`, `next`, `previous`, `revision`, `status` |
| Item line | `entries`, `refs`, `title`, `type`, `year` |
| Entry | `date`, `episode`, `rating`, `review`, `season` |

Fields added by future versions of this spec or by extensions are
sorted in with the rest, not appended.

### Line structure

- **One author line, one line per item.** An item's entries live
  inside its item line, so editing one entry changes only that item's
  line.
- **Entries ordered oldest first**, by `date` compared as a string (so
  `2019` before `2019-05` before `2019-05-04`), with undated entries
  before dated ones, and ties kept in the order they were entered. For `tv` items
  this means entries are ordered by date, not by season or episode.
- **No volatile fields on item lines.** `revision` lives only on the
  author line, so a revision bump changes exactly one line. Generators
  SHOULD NOT add per-item timestamps or other values that change
  without the underlying rating changing.
- **Byte-identical duplicate item lines dropped** before signing.
  SJSONL forbids them, and they carry no information.

These rules keep unchanged items byte-identical across an author's
revisions, which is where nearly all of the patch-size and storage
benefit comes from. Sharing lines *between* authors is limited by
design: an item line carries that author's entries, so two authors'
lines match only when their entries for an item are identical (or
both are absent).

## Validation

### What servers check

A server accepting a ratingset checks, and rejects the document if any
check fails:

1. The document is within the server's size limit.
2. It is a valid SJSONL document with a valid signature (for a patch,
   after applying it to its base).
3. It has exactly one author line.
4. The author line's `id` matches the signing key.
5. `revision` is at least 1, greater than the latest revision the
   server has accepted for that author, and no greater than the
   [revision ceiling](#revision-ceiling).
6. The author's ID is not closed (see [Key status](#key-status)): the
   server hasn't accepted a `moved` revision or a valid successor
   document for it. If the server has accepted a `retired` revision,
   only a `moved` revision is accepted.
7. If the server has accepted a revision with `next` for this author,
   this revision has the same `next`. The same rule applies to
   `previous`.
8. `next` and `previous`, if present, are 64 lowercase hex characters
   and differ from `id`. `status`, if present, is `retired` or `moved`,
   and `moved` comes with `next`.
9. If `previous` is present and the server holds the predecessor's
   documents, the predecessor's `next` equals this document's `id`.
   Accepting the document then closes the predecessor ID.

Servers keep a closed ID's last accepted revision available as that
author's current document, so consumers arriving later still find the
final status.

Servers SHOULD also reject an author line without a valid rating
scale.

Servers don't validate item lines. A document with invalid items is
accepted and stored as is.

Servers set their own size limits, and this spec doesn't fix one.
Generators should expect documents above a few megabytes to be
rejected.

### What consumers check

Consumers check the document the same way servers do, then read item
lines leniently. An item line that doesn't parse, or is invalid under
[Item line](#item-line) or [Entry](#entry), is skipped. The rest of
the document is still used.

## Open questions

1. **HTML escaping.** [Encoding rules](#encoding-rules) says not to
   escape `<`, `>`, and `&`, but the client encodes with
   `json.Marshal`, which escapes them. Fix the client
   (`SetEscapeHTML(false)`) or relax the rule.
2. **Spoilers.** Should an entry be able to mark its review as
   containing spoilers? An optional boolean on the entry (say
   `"spoilers": true`) is the simplest form, and it doesn't commit the
   format to inline markup. Until it's defined, a client can add it as
   an extension field.
3. **Successor without the predecessor.** A server that doesn't hold
   the predecessor's documents can't check `previous` (check 9). Should
   it reject the document, or accept it and leave the link for
   consumers to verify? Accepting is friendlier to federation, but the
   server then can't close the predecessor ID.
4. **Disavowing stolen revisions.** After a theft, revisions published
   by the thief stay valid under the old ID. The successor key could be
   allowed to mark predecessor revisions above some number as not the
   author's. That needs trusted acceptance times, like the delegation
   draft's, and is left for later.
5. **Delegation.** If delegation is added, delegates sign the whole
   document, author line included. Only root-signed revisions should be
   able to set `next`, `previous`, or `status`, and closing an ID should
   void every grant.
6. **Season ranges.** An author who reviews "seasons 1–3" together
   has to pick: one series-level entry, or the same review copied into
   three season entries. A `seasons` range field would capture it
   directly, at the cost of another way to say the same thing.
7. **Episode entries.** `episode` is defined so episode reviews have a
   place, but nothing uses it yet. If episode logging becomes common,
   a series could gain hundreds of entries on one line, and editing
   any of them rewrites that line. Splitting a series across lines
   (per season, say) would need a rule for merging lines that share
   refs.
