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
Field order is lexicographic. The reference client emits this for the
user line today; its title and review structs still need reordering.
-->

## Line encoding

A ratingset is an [SJSONL](/specs/sjsonl/) document. All of the SJSONL [line encoding recommendations](/specs/sjsonl/#line-encoding-recommendations) apply. This section narrows them for ratingset lines, so that independent clients encoding the same data produce the same bytes.

As in SJSONL, these rules are for generators only. Servers and consumers MUST accept any line that is valid under the schema, and MUST NOT re-encode lines before hashing, storing, or republishing them.

### Encoding

Clients SHOULD encode every ratingset line as follows:

- **Compact form**, with no insignificant whitespace.
- **Object keys are sorted lexicographically** at every nesting level: on the user line, title lines, reviews, and `refs`. This is the SJSONL default, needs no per-field table, and any JSON library can produce it.
- **Absent optional fields are omitted**, not written as `null`, `""`, `[]`, or `{}`.
- **Strings are UTF-8, escaping only what JSON requires.** Do not escape `<`, `>`, `&`, or non-ASCII characters. Go clients must use a `json.Encoder` with `SetEscapeHTML(false)` (and strip the trailing newline it adds) rather than `json.Marshal`.
- **Strings are Unicode NFC-normalized.** This matters most for titles: `Amélie` typed with a precomposed `é` and with `e` plus a combining accent are different bytes, and therefore different lines.
- **Dates** use `YYYY-MM-DD`.
- **Numbers** are plain decimal integers.

### Field order

All keys are ASCII, so lexicographic order is plain byte order. For the fields defined today:

| Line | Fields, in order |
|------|------------------|
| User line | `id`, `max_rating`, `min_rating`, `revision` |
| Title line | `name`, `refs`, `reviews`, `type`, `year` |
| Review (within `reviews`) | `comment`, `date`, `rating` |

Fields added by future schema versions or extensions are sorted in with the rest, not appended.

### Line structure

- **One user line, one line per title.** A title's reviews live inside its title line, so editing one review changes only that title's line.
- **Reviews are ordered oldest first**, with undated reviews before dated ones and ties kept in the order they were entered.
- **`revision` lives only on the user line.** A revision bump therefore changes exactly one line. Clients SHOULD NOT add per-title timestamps or other values that change without the underlying rating changing.
- **Byte-identical duplicate title lines are dropped** before signing. SJSONL forbids them, and they carry no information.

### Expected benefit

These rules keep unchanged titles byte-identical across a user's revisions, which is where nearly all of the patch-size and storage benefit comes from. Sharing lines *between* users is limited by design: a title line carries that user's reviews, so two users' lines match only when their reviews of a title are identical (or both are absent).
