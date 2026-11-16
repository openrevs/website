---
title: Ratingset
parent: Specifications
published: false
permalink: /specs/ratingset/
---

# Ratingset Specification

<!--
DRAFT. Describes what the reference implementation (github.com/openrevs/revs)
does as of commit 82c8623. Where this draft goes beyond what the code
checks, it says so. Open questions are collected at the end.
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
{"type":"movie","name":"Pulp Fiction","year":1994,"refs":{"imdb":"tt0110912","tmdb":"680","wikidata":"Q104123"},"reviews":[{"date":"1997-07-07","rating":9,"comment":"Great"},{"date":"2020-01-01","rating":8}]}
{"type":"movie","name":"Rocky","year":1976,"reviews":[{"rating":7}]}
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

## User line

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `id` | string | yes | The author's user ID (see below). |
| `revision` | integer ≥ 1 | yes | The document's revision number. |
| `min_rating` | integer | no | Lowest value on the rating scale. |
| `max_rating` | integer | no | Highest value on the rating scale. |
| `email` | string | no | A contact address the author chooses to publish. |

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

### Rating scale

`min_rating` and `max_rating` declare an inclusive range of integers
that every `rating` in the document uses. See
[Rating scales](/specs/ratings/) for how consumers interpret and
convert ratings.

A scale is **declared** when `max_rating` is present and greater than
`min_rating` (an absent `min_rating` means 0). When no scale is
declared, consumers assume 0–5.

The reference client publishes `min_rating` 0 and `max_rating` 10 (half
stars).

## Title line

A title line describes one item and holds the author's reviews of it.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `name` | string | yes | The item's title. |
| `type` | string | no | The kind of item, e.g. `"movie"`. |
| `year` | integer | no | Year of release. |
| `refs` | object of string → string | no | IDs of the item in other catalogs. |
| `reviews` | array of review objects | no | The author's reviews, oldest first. |

`name` MUST be non-empty after trimming whitespace. Consumers skip title
lines without one, rather than rejecting the whole document.

### Type

`type` identifies what kind of thing the title is. The only value
defined so far is `movie`. Consumers compare `type` without regard to
case and skip titles whose type they don't support.

A title without `type` is currently treated as a movie. *(See open
questions.)*

### Refs

`refs` maps a catalog name to the item's ID in that catalog. It helps
consumers match the same item across documents more reliably than name
and year alone. Defined keys:

| Key | Value | Example |
|-----|-------|---------|
| `imdb` | IMDb title ID | `tt0110912` |
| `tmdb` | TMDB movie ID (numeric) | `680` |
| `wikidata` | Wikidata item ID | `Q104123` |

Generators SHOULD emit keys in lowercase and values in the forms shown.
Consumers match keys without regard to case and SHOULD accept common
variants of the values: a URL, a TMDB slug such as `680-pulp-fiction`,
or a lowercase Wikidata `q`. Consumers ignore keys they don't know.

Generators SHOULD omit `refs` when it would be empty.

### Matching titles

Consumers that merge titles from several documents match them in this
order:

1. by `wikidata`, then `imdb`, then `tmdb` ref, when present;
2. otherwise by exact `name` and `year`.

*(This describes the reference client; it is not a requirement on
other consumers.)*

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
- A `rating` outside the declared scale is treated as unrated.
- Reviews within a title SHOULD be ordered oldest first, with undated
  reviews before dated ones.

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

1. The document is at most 1 MiB.
2. It is a valid SJSONL document with a valid signature (for a patch,
   after applying it to its base).
3. It has exactly one user line.
4. The user line's `id` matches the signing key.
5. `revision` is at least 1 and greater than the latest revision the
   server has accepted for that user.

Servers don't validate title lines. A document with malformed titles is
accepted and stored as is.

### What consumers check

Consumers verify the signature and user ID the same way, then read
title lines leniently: a title line that doesn't parse, or has no
`name`, or has an unsupported `type`, is skipped. The rest of the
document is still used.

## Unsigned ratingsets

For import and export between clients, the reference client also
accepts **unsigned** ratingsets: the same data lines with no SJSONL
header. An unsigned file may omit the user line, in which case its
ratings are taken to use the 0–5 scale. Unsigned files carry no proof
of authorship, and servers do not accept them.

## Open questions

1. **Field order on the user line.** The line encoding draft says the
   user line uses schema order (`id`, `email`, `min_rating`,
   `max_rating`, `revision`). But the reference client rewrites the
   user line when it sets `revision` (`client/push.go` `signWithRev`),
   by decoding it into a Go map and re-encoding it. That emits keys in
   alphabetical order: `id`, `max_rating`, `min_rating`, `revision`.
   Either the encoding draft or the client needs to change.
2. **HTML escaping.** The line encoding draft says not to escape `<`,
   `>`, and `&`, but the client encodes with `json.Marshal`, which
   does. Same choice as above.
3. **Untyped titles.** Should `type` be required? Today a title without
   it is read as a movie. That's harmless while movies are the only
   type, but it becomes ambiguous once there are others.
4. **Name and year matching.** Matching by name uses exact string
   equality, so case and Unicode normalization differences produce
   separate titles. The line encoding draft requires NFC; should
   consumers also normalize, or compare case-insensitively?
5. **Required scale.** Should `min_rating` and `max_rating` be required
   on signed documents? The 0–5 fallback exists only for documents
   published by earlier versions of the client.
6. **Rating constraints.** Should a rating outside the declared scale
   make the document invalid, instead of being treated as unrated?
   Servers could check this, since it needs only the document.
7. **Review dates.** The format is `YYYY-MM-DD`, but nothing enforces
   it. The older server-rendered export in `user.go`
   (`generateRatingsFile`) writes RFC 3339 timestamps and an uppercase
   `TMDB` ref key. Is that code still live? If so, it should be fixed
   or removed.
8. **`email`.** Nothing in revs reads it. Keep it, or drop it from the
   schema?
9. **Size limit.** The 1 MiB cap is a server setting today. Should it be
   part of the spec, so clients know when to stop?
