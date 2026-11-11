---
title: revs Line Encoding (fragment)
parent: Specifications
published: false
permalink: /specs/revs-line-encoding/
---

<!--
DRAFT FRAGMENT for issue #6. There is no revs spec page yet; this is the
"Line encoding" section intended to be dropped into it. No front matter,
so Jekyll copies it as a static file instead of publishing it as a page.
Field lists reflect what the reference client emits today
(revs.User2 / revs.Title2 / revs.Review2).
-->

## Line encoding

A ratingset is an [SJSONL](/specs/sjsonl/) document. All of the SJSONL [line encoding recommendations](/specs/sjsonl/#line-encoding-recommendations) apply. This section narrows them for ratingset lines, so that independent clients encoding the same data produce the same bytes.

As in SJSONL, these rules are for generators only. Servers and consumers MUST accept any line that is valid under the schema, and MUST NOT re-encode lines before hashing, storing, or republishing them.

### Encoding

Clients SHOULD encode every ratingset line as follows:

- **Compact form**, with no insignificant whitespace.
- **Field order is the schema order** listed below, not alphabetical. This matches what the reference client emits and lets lines read naturally (`type`, then `name`, then `year`, …).
- **Objects with free-form keys** (`refs`) have their keys sorted lexicographically.
- **Absent optional fields are omitted**, not written as `null`, `""`, `[]`, or `{}`.
- **Strings are UTF-8, escaping only what JSON requires.** Do not escape `<`, `>`, `&`, or non-ASCII characters. Go clients must use a `json.Encoder` with `SetEscapeHTML(false)` (and strip the trailing newline it adds) rather than `json.Marshal`.
- **Strings are Unicode NFC-normalized.** This matters most for titles: `Amélie` typed with a precomposed `é` and with `e` plus a combining accent are different bytes, and therefore different lines.
- **Dates** use `YYYY-MM-DD`.
- **Numbers** are plain decimal integers.

### Field order

| Line | Fields, in order |
|------|------------------|
| User line | `id`, `email`, `min_rating`, `max_rating`, `revision` |
| Title line | `type`, `name`, `year`, `refs`, `reviews` |
| Review (within `reviews`) | `date`, `rating`, `comment` |

Fields not in this table (from future schema versions or extensions) come after the listed ones, sorted lexicographically.

### Line structure

- **One user line, one line per title.** A title's reviews live inside its title line, so editing one review changes only that title's line.
- **Reviews are ordered oldest first**, with undated reviews before dated ones and ties kept in the order they were entered.
- **`revision` lives only on the user line.** A revision bump therefore changes exactly one line. Clients SHOULD NOT add per-title timestamps or other values that change without the underlying rating changing.
- **Byte-identical duplicate title lines are dropped** before signing. SJSONL forbids them, and they carry no information.

### Expected benefit

These rules keep unchanged titles byte-identical across a user's revisions, which is where nearly all of the patch-size and storage benefit comes from. Sharing lines *between* users is limited by design: a title line carries that user's reviews, so two users' lines match only when their reviews of a title are identical (or both are absent).
