---
title: Signed JSONL
parent: Specifications
nav_order: 2
permalink: /specs/sjsonl/
---

# Signed JSONL Specification

**Version 0.1**

This document specifies the SJSONL format for signing, diffing, and patching JSON Lines documents.

## Overview

SJSONL structures documents as [JSON Lines](https://jsonlines.org) and treats each document as a *set* of lines. Signing then reduces to hashing lines, and diffing reduces to set operations. There's no canonicalization and no signature embedding tricks.

### Goals

- Documents can be signed and verified against a public key
- Documents can be diffed and patched, including by third parties who cannot sign
- Familiar formats and encodings (JSONL, SHA256, Ed25519, hex, base64)
- Simple design and easy implementation

### Rationale

[Signing JSON is difficult](https://www.latacora.com/blog/2019/07/24/how-not-to/). A signature can't be stored inside a document without changing it, which leaves hacks to embed and extract it. Canonicalizing JSON is non-standard, complicated, and inconsistently supported, so the usual advice is "don't sign JSON" — sign the bytes and convey the signature separately.

Diffing and patching are no easier. A textual diff is useless when the document is one long line, and semantic diffs like JSON merge-patch conflict with byte-oriented signing, since a patched document can be re-encoded any number of ways.

Structuring the document as a set of lines sidesteps all of this:

- **Signing is simple.** Each line is hashed as an exact byte sequence; the sorted hashes are signed. The signature lives in a header line that isn't part of the signed content, so nothing needs to be embedded or extracted.
- **Diff/patch is simple.** A diff between two documents is just the set of lines removed and added. Removals are identified by short hash prefixes.
- **Patches carry the target's signature**, so applying a patch yields a fully signed document — third parties can generate and apply patches without ever holding a signing key.

Line orientation also helps on the server side:

- Because signing covers a *set* of lines rather than a specific byte sequence, servers can offer patches between arbitrary versions.
- Multiple versions of a document can be stored efficiently by deduplicating lines across revisions.

The tradeoff is that data must fit a line-centric structure (a catalog, blog posts, reviews, paragraph blocks, …).

## Documents

All SJSONL files, whether signed documents or patch files, are [JSON Lines](https://jsonlines.org) (JSONL) files, and all JSONL rules apply. A single trailing newline at the end of a file is permitted and ignored.

### Input

The input document (what is being signed) is treated as a line **set**:

- **Lines are unordered.** Documents with the same lines in a different order are equivalent, and line order in a signed document is not significant.
- **Duplicate lines are not allowed.** For this test, a line's content has leading and trailing whitespace stripped.
- **Every line must be valid JSON.** Empty lines are not allowed.

Those are the only input requirements beyond those of JSON Lines. The following is a valid input:

```json
{"name": "Alice", "age": 42}
{"name": "Bob", "age": 30}
{"address": {"street": "Main", "number":12}}
null
95
```

## Line hashes

Each line's hash is the SHA256 of the line's bytes with leading and trailing whitespace removed.

Hashes are encoded as lowercase hex wherever they appear as strings.

Keys and signatures are encoded as standard base64 ([RFC 4648 §4](https://www.rfc-editor.org/rfc/rfc4648#section-4)) with padding. Every value has exactly one valid encoding: encoders MUST produce the canonical form, and decoders MUST reject anything else, including non-zero trailing bits, missing or extra padding, whitespace, and the URL-safe alphabet.

## Header line

The first line of a signed document or patch file MUST be a header line: a JSON object with the following fields, some of which apply only to patches.

| Field | Applies to | Description |
|-------|-----------|-------------|
| `sjsonl` | both | Marker and file type: `"doc"` for a signed document, `"patch"` for a patch |
| `version` | both | Format version. Currently the only supported version is `"0.1"` |
| `key` | both | The Ed25519 public key, encoded as base64 |
| `sig` | both | The Ed25519 signature, encoded as base64. For patches, this is the signature of the **patched** document, not of the patch itself |
| `base` | patch only | The document hash of the base document, identifying the expected source of the patch |
| `target` | patch only | The document hash of the patched (target) document |
| `rm` | patch only | A JSON array of hash prefixes identifying lines to remove from the base document |

The header line is not part of the signed line set.

## Signing

The signature is computed as follows:

1. Compute the hash of each line as described above, excluding the header line and an optional empty last line (if the file ends with `\n`).
2. Sort the hashes in ascending order.
3. Concatenate the sorted hashes, as raw 32-byte values, into a single byte string. This is the message to be signed. (An empty document produces an empty message, which is still signable.)
4. Sign the message with the signer's Ed25519 private key, or verify it against the `sig` and `key` fields of the header line.

A signed document is the input document plus the header line:

```json
{"sjsonl":"doc","version":"0.1","key":"Hdt5Ux+sYIXrVy62PJ7TzYSoXgjAjwoG8oOwflbgQag=","sig":"4A3QVt9/DvASKQuXlTolqT5hJVEhOW2PyNg84ucbW5dYQCm6P5ivlB/NvMeaVSYytZK/xwoB5X/DVHpeYjJ4Cw=="}
{"name": "Bob", "age": 30}
null
{"name": "Alice", "age": 42}
{"address": {"street": "Main", "number":12}}
95
```

### Document hash

A document's hash is the SHA256 of the signing message from step 3 above, encoded as lowercase hex. It identifies a specific line set and is used as the `base` and `target` references in patches and for general purpose document identification.

## Patching

Patching turns a base/source document into a new (target) document given a patch file. Two documents may be *diffed* to generate a patch. Because documents are line sets, a diff is a set operation: find the lines to remove and the lines to add. Only whole-line operations are supported — if any part of a line changes, the whole line is replaced.

A patch file consists of:

- A header line with `sjsonl` set to `"patch"`, carrying:
  - `base` — the document hash of the base document
  - `target` — the document hash of the patched (target) document
  - `rm` — hash prefixes of the lines to remove
  - `key` and `sig` — the signature data for the **patched** (target) document. `key` and `sig` are both **optional**.
- The lines to add, one per line, verbatim

The optionality of signature data is to allow using the same diff/patch structure within internal and trusted environments.

Example — a patch that changes Alice's age in the document above:

```json
{"sjsonl":"patch","version":"0.1","key":"Hdt5Ux+sYIXrVy62PJ7TzYSoXgjAjwoG8oOwflbgQag=","sig":"yROn8+SLvFyMUOZEbBKS6dluwE13bEVAQyTuPg+pmaYG1yv84lEl1zPHYDedgLDA56cQ3FPB7zCvGhZGEKJFBQ==","base":"20728fa9354b71b9b05f34b3e7bf8f812a00984bc3ee9446069aa54a65b2886e","target":"775a21e81092bede93eb474903b3a8a7cf5d557d38676cc1fc4906e4c2cde879","rm":["7a"]}
{"name": "Alice", "age": 50}
```

### Deletions

Deletions are represented as a JSON array of hash prefixes. Each prefix is a string of lowercase hex characters.

**Consumers** MUST delete every line of the base document whose hash starts with any listed prefix. A prefix may match multiple lines. It is an error if a prefix matches no lines.

**Generators** may use any prefix length, from a single character up to the full hash. The only requirement is that each prefix match exactly the lines intended for deletion — the generator is responsible for checking its prefixes against the base document. Any strategy that satisfies this is valid: emitting full hashes, computing minimal unique prefixes, or simply truncating to a fixed length and extending on the rare unintended match (16 characters is recommended — at 64 bits, an accidental collision with another line's hash is negligible at any practical document size).

Note that an over-matching prefix fails closed: the unintended deletion causes signature verification of the patched document to fail, so a bad patch is rejected rather than silently corrupting data.

An empty array is valid and deletes nothing (a pure-additions patch). A zero-length prefix (`""`) is also valid and matches every line, deleting the entire base document; this makes a full-replacement patch expressible without a separate operation.

### Applying a patch

1. Verify that the `base` field matches the base document's hash.
2. Remove every line from the base document whose hash matches an `rm` prefix.
3. Add each of the patch's data lines to the set. All input rules apply to the result (no duplicates, etc.).
4. Form the result document from the patch's `key` and `sig` as a `"doc"` header line plus the resulting line set, and verify its signature as described in [Signing](#signing).

Because the patch carries the signature of the target document, a successfully applied and verified patch yields a fully signed document. This doubles as patch verification, and is why the patch file itself is not signed.
