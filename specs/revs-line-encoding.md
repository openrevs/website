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
Field order is lexicographic. The reference client emits this encoding
(revs.Author / revs.Item / revs.Entry, written with revs.EncodeLine).
-->

## Line encoding

A ratingset is an [SJSONL](/specs/sjsonl/) document. All of the SJSONL [line encoding recommendations](/specs/sjsonl/#line-encoding-recommendations) apply. This section narrows them for ratingset lines, so that independent clients encoding the same data produce the same bytes.

As in SJSONL, these rules are for generators only. Servers and consumers MUST accept any line that is valid under the schema, and MUST NOT re-encode lines before hashing, storing, or republishing them.

### Encoding

Clients SHOULD encode every ratingset line as follows:

- **Compact form**, with no insignificant whitespace.
- **Object keys are sorted lexicographically** at every nesting level: on the author line, item lines, entries, and `refs`. This is the SJSONL default, needs no per-field table, and any JSON library can produce it.
- **Absent optional fields are omitted**, not written as `null`, `""`, `[]`, or `{}`.
- **Strings are UTF-8, escaping only what JSON requires.** Do not escape `<`, `>`, `&`, or non-ASCII characters. Go clients must use a `json.Encoder` with `SetEscapeHTML(false)` (and strip the trailing newline it adds) rather than `json.Marshal`.
- **Strings are Unicode NFC-normalized.** This matters most for `title`: `Amélie` typed with a precomposed `é` and with `e` plus a combining accent are different bytes, and therefore different lines.
- **Dates** use `YYYY-MM-DD`.
- **Numbers** are plain decimal integers.

### Field order

All keys are ASCII, so lexicographic order is plain byte order. For the fields defined today:

| Line | Fields, in order |
|------|------------------|
| Author line | `id`, `max_rating`, `min_rating`, `revision` |
| Item line | `entries`, `refs`, `title`, `type`, `year` |
| Entry (within `entries`) | `date`, `rating`, `review` |

Fields added by future schema versions or extensions are sorted in with the rest, not appended.

### Line structure

- **One author line, one line per item.** An item's entries live inside its item line, so editing one entry changes only that item's line.
- **Entries are ordered oldest first**, with undated entries before dated ones and ties kept in the order they were entered.
- **`revision` lives only on the author line.** A revision bump therefore changes exactly one line. Clients SHOULD NOT add per-item timestamps or other values that change without the underlying rating changing.
- **Byte-identical duplicate item lines are dropped** before signing. SJSONL forbids them, and they carry no information.

### Expected benefit

These rules keep unchanged items byte-identical across an author's revisions, which is where nearly all of the patch-size and storage benefit comes from. Sharing lines *between* authors is limited by design: an item line carries that author's entries, so two authors' lines match only when their entries for an item are identical (or both are absent).
