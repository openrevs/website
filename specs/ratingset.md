---
title: Ratingset
parent: Specifications
published: false
permalink: /specs/ratingset/
---

# Ratingset Specification

<!--
DRAFT. Started from what the reference implementation (github.com/openrevs/revs)
does as of commit 82c8623, then revised in review. Where the spec now
differs from the code, a "Reference client" note says so. Open questions
are collected at the end.
Sources: ratingset.go (User2, Title2, Review2, ParseRatingset),
json_lines.go, keys/keys.go, handlers.go (acceptDocument),
client/push.go (signWithRev), client/history.go (Commit),
collection/document.go (buildContent, parseRatingset, mergeTitles),
collection/rating.go, collection/fields.go, collection/remote.go.
-->

A **ratingset** is one user's ratings and reviews, published as a single
[SJSONL](/specs/sjsonl/) document. It contains one **user line**, which
identifies the author and declares their rating scale, and one **title
line** for each item they've reviewed. A title line holds all of that
user's reviews of the item.

The keywords MUST, SHOULD, and MAY are used as described in RFC 2119.

## Example

```
{"sjsonl":"1","key":"…","sig":"…"}
{"id":"601b27ee…","max_rating":10,"min_rating":0,"revision":4}
{"name":"Pulp Fiction","refs":{"imdb":"tt0110912","tmdb":"680","wikidata":"Q104123"},"reviews":[{"comment":"Great","date":"1997-07-07","rating":9},{"date":"2020-01-01","rating":8}],"type":"movie","year":1994}
{"name":"Rocky","reviews":[{"rating":7}],"type":"movie","year":1976}
```

The first line is the SJSONL header, defined by the SJSONL spec. The
data lines follow.

## Document

A ratingset MUST be a valid, signed SJSONL document. Its data lines
consist of:

- exactly one user line, and
- zero or more title lines.

The user line and title lines may appear in any order. Consumers MUST
NOT rely on the user line being first. Generators SHOULD put it first.

**How lines are told apart:** a data line that has an `id` member is
the user line; every other data line is a title line. A title line
therefore MUST NOT have an `id` member. A document with more than one
line carrying `id` is invalid.

Every data line MUST be a JSON object.

## Privacy

A ratingset identifies its author only by a key-derived ID. It carries
no real-world identity: no name, email address, or other contact
details. Linking an ID to a person, if anyone wants that, is left to
other applications.

Generators MUST NOT add identifying fields to the user line, even
though the [unknown fields](#unknown-fields) rule would let them.

## User line

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `id` | string | yes | The author's user ID (see below). |
| `revision` | integer ≥ 1 | yes | The document's revision number. |
| `min_rating` | integer | yes | Lowest value on the rating scale. |
| `max_rating` | integer | yes | Highest value on the rating scale. |

### User ID

The user ID is the SHA-256 hash of the 32-byte Ed25519 public key that
signed the document, written as 64 lowercase hex characters. A ratingset
whose `id` doesn't match its signing key is invalid. That rule binds a
document to its author: only the key holder can publish under that ID.

### Revision

`revision` orders an author's documents. Each new document from an
author MUST have a higher `revision` than every earlier one. Revisions
don't need to be consecutive.

Servers reject a document whose `revision` is missing or less than 1,
or not greater than the latest one they've accepted for that user.

Clients SHOULD assign a new revision only when content has changed.
`revision` is the only field that changes when nothing else does, which
is why it lives on the user line and not on title lines.

## Ratings

### Rating scale

`min_rating` and `max_rating` declare the scale that every `rating` in
the document uses. The scale is the inclusive range of integers
`min_rating`..`max_rating`. `max_rating` MUST be greater than
`min_rating`. A user line without a valid scale is invalid.

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

then map `fraction` onto the consumer's own scale. The reference client
rounds to the nearest half star.

### Notes for generators

- Declare the scale your ratings actually use, and keep it the same
  across a user's documents where you can. Changing the scale changes
  every title line, so the next revision rewrites the whole document.
- Pick a scale whose steps match what users can enter. A 0–10 scale
  for half stars converts exactly. A scale that's too coarse loses
  precision for everyone who reads the document.

## Title line

A title line describes one item and holds the author's reviews of it.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `type` | string | yes | The kind of item, e.g. `"movie"`. |
| `name` | string | yes | The item's title. |
| `year` | integer | no | Year of release. |
| `refs` | object of string → string | no | IDs of the item in other catalogs. |
| `reviews` | array of review objects | no | The author's reviews. |

`name` MUST be non-empty after trimming whitespace.

A title line that breaks any rule in this section or in
[Review](#review) is invalid. Consumers skip invalid title lines and
still use the rest of the document (see [Validation](#validation)).

### Type

`type` says what kind of thing the title is. The rest of the title
depends on it: which `refs` keys apply, and what `year` means. The only
value defined so far is `movie`. Consumers compare `type` without
regard to case, and skip titles whose type they don't support.

`type` is required so that new kinds of item (TV series, books, games)
can be added later without making existing documents ambiguous.

*Reference client: it reads a title without `type` as a movie.*

### Refs

`refs` maps a catalog name to the item's ID in that catalog. It lets
consumers match the same item across documents more reliably than name
and year alone. Defined keys for `movie`:

| Key | Value | Example |
|-----|-------|---------|
| `imdb` | IMDb title ID | `tt0110912` |
| `wikidata` | Wikidata item ID | `Q104123` |
| `tmdb` | TMDB movie ID (numeric) | `680` |

Generators SHOULD emit keys in lowercase and values in the forms shown,
and SHOULD include `imdb` when it's known. Consumers match keys without
regard to case, and SHOULD accept common variants of the values: a URL,
a TMDB slug such as `680-pulp-fiction`, or a lowercase Wikidata `q`.
Consumers ignore keys they don't know.

Generators SHOULD omit `refs` when it would be empty.

### Matching titles

Consumers that merge titles from several documents need to decide when
two title lines describe the same item. The rule for refs:

- Two titles of the same `type` **match** when they have at least one
  ref key in common and the values agree for **every** key they have in
  common.
- They **conflict** when any key they have in common has a different
  value. A conflict means one of the documents has a wrong ID.

Since every key they share has to agree, the order the keys are
checked in doesn't change the result. Consumers that need one key per
title (for an index, say) SHOULD prefer them in this order: `imdb`,
`wikidata`, `tmdb`. IMDb IDs are the most widely available and are
unambiguous across types. TMDB IDs are only unique within a media type,
so they come last.

How to handle conflicting titles (keep them apart, or pick one key to
trust), and how to match titles that have no refs in common (by name
and year, by fuzzy matching, or not at all), are up to the consumer.
Keeping conflicting titles apart is the safe default, because merging
them on a wrong ID pulls the wrong reviews into a title.

*Reference client: it checks `wikidata`, then `imdb`, then `tmdb`, and
uses the first key the two titles share. It doesn't check for
conflicts. Without a shared ref, it matches on exact `name` and
`year`.*

## Review

A review is one occasion of the author rating or commenting on a title,
such as one viewing of a movie.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `date` | string `YYYY-MM-DD` | no | When the review happened. |
| `rating` | integer | no | The rating, on the document's scale. |
| `comment` | string | no | Free-text review. |

All fields are optional, so a review can be a bare record that a
viewing happened.

- A review without `rating` is **unrated**, which is different from a
  rating of `min_rating`.
- A `rating`, if present, MUST be within the declared scale. A title
  line containing an out-of-range rating is invalid.
- A `date`, if present, MUST be a valid calendar date in `YYYY-MM-DD`
  form. A title line containing any other date is invalid.
- The order of reviews carries no meaning. Consumers sort reviews by
  `date` themselves when they need an order. Generators order reviews
  as described in [Line encoding](/specs/revs-line-encoding/), which
  keeps the line's bytes the same from revision to revision.

*Reference client: it reads an out-of-range rating as unrated, and
doesn't check date format.*

### Comments

`comment` is plain text. Line breaks are written as `\n`. Consumers
MUST NOT interpret a comment as HTML or any other markup. To display a
comment, render it as text.

This spec sets no length limit on comments. A comment is limited only
by the document's size. Consumers MAY truncate long comments for
display.

## Unknown fields

Consumers MUST ignore fields they don't recognize on the user line,
title lines, and reviews. Future versions of this spec and application
extensions may add fields.

## Encoding

A ratingset's line encoding (field order, escaping, normalization) is
specified in [Line encoding](/specs/revs-line-encoding/). Those rules
apply only to generators. Consumers and servers MUST accept any line
that is valid under this spec, and MUST NOT re-encode lines.

## Validation

### What servers check

A server accepting a ratingset checks, and rejects the document if any
check fails:

1. The document is within the server's size limit.
2. It is a valid SJSONL document with a valid signature (for a patch,
   after applying it to its base).
3. It has exactly one user line.
4. The user line's `id` matches the signing key.
5. `revision` is at least 1 and greater than the latest revision the
   server has accepted for that user.

Servers SHOULD also reject a user line without a valid rating scale.

Servers don't validate title lines. A document with invalid titles is
accepted and stored as is.

Servers set their own size limits, and this spec doesn't fix one.
Generators should expect documents above a few megabytes to be
rejected. *(Reference server: 1 MiB.)*

### What consumers check

Consumers check the document the same way servers do, then read title
lines leniently. A title line that doesn't parse, or is invalid under
[Title line](#title-line) or [Review](#review), is skipped. The rest
of the document is still used.

## Open questions

1. **HTML escaping.** The line encoding draft says not to escape `<`,
   `>`, and `&`, but the client encodes with `json.Marshal`, which
   escapes them. Fix the client (`SetEscapeHTML(false)`) or relax the
   draft.
2. **Spoilers.** Should a review be able to mark its comment as
   containing spoilers? An optional boolean on the review (say
   `"spoilers": true`) is the simplest form, and it doesn't commit the
   format to inline markup. Until it's defined, a client can add it as
   an extension field.
