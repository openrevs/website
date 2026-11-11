---
title: Publishing
parent: Specifications
published: false
permalink: /specs/publishing/
---

# Publishing Plan

How the server publishes the ratings corpus to clients and peer servers.
Captured 2026-08-09 after design review.

## Overview

The server ingests signed sjsonl ratingset documents from users and
publishes the corpus as a chain of **patches** (regular, small) plus
occasional **snapshots** (full corpus dumps). Consumers track a
monotonically increasing **epoch** number and stay current by applying
patches in sequence; new or badly stale consumers bootstrap from a
snapshot. Signed **manifests** describe every publication and are
fetchable independently of the artifacts they describe.

## Ingest

Uploads are handled synchronously — the queue/processor design is gone.
An upload is either a full signed document or a signed sjsonl patch
against the user's latest accepted document. The upload handler:

1. If the body is a patch: derives the user id from the patch's key,
   checks the patch `base` equals the hash of that user's latest
   accepted document (else `409` with status `base_mismatch` and the
   latest rev), and applies it. The result is the full signed target
   document, which is handled exactly like a full upload from here on.
2. Checks the document is at most 1 MiB (`maxDocumentSize`). The same
   limit caps the upload body, but it is checked again after patching,
   so patches can't grow a document past it.
3. Verifies the document (sjsonl signature, user id matches signing key).
4. Checks the asserted rev is strictly greater than the latest accepted
   rev for that user.
5. Persists the document.
6. Returns a final verdict: `200` accepted, `400` invalid,
   `409` stale rev or patch base mismatch. JSON body carries the reason.

Patches only save upload bandwidth; they don't change trust. The
author's signature covers the full target document, and the server
stores and republishes exactly that document.

Conflict verdicts (`stale` and `base_mismatch`) carry the rev and hash
of the user's latest accepted document.

The client keeps the author's version history (`client.History`):
every version it signs, the newest in full and older ones as signed
reverse patches, capped at 100 by default. One history is shared by all
the servers an author pushes to, and it assigns revisions, so a version
has the same rev everywhere. Servers can pull from each other, so a
server may hold any of the author's versions. To push, the client sends a
patch against the version the server is believed to hold (if smaller
than the full document). On `base_mismatch` it uses the reported
hash: if that version is in the history, it re-diffs against it,
otherwise it sends the full document. A conflict whose hash is the
version being pushed means the server already has it.

Revision numbers are **client-asserted** and live inside the signed
document, where consumers can verify them against the author's
signature. The server enforces only strict monotonicity. The client
spec SHOULD say: bump the rev only when content actually changed
(compare the doc hash with the rev held constant). The server does not
police this — an empty rev bump just produces a tiny patch. Abuse and
quotas are handled separately and are out of scope here.

## Storage

Document blobs are content-addressed in object storage (local
filesystem for now, behind a minimal Put/Get interface):

    docs/<hash[:2]>/<hash>

keyed by the sjsonl doc hash. This gives immutability, dedup of
identical uploads, no user-controlled path segments, and makes the
manifest `hash` field double as the storage key.

The database tracks metadata only:

- `documents(userid, rev, hash, size, received_time)` — unique on
  `(userid, rev)`.
- `epochs(epoch, kind, manifest_hash, created)` — the cut ledger.
- `published_head(userid, rev)` — what the last cut shipped; diffs are
  computed from this, and it defines "changed since last epoch".

Every accepted rev is retained. GC is a future policy; the
content-addressed layout makes it a mark-and-sweep from manifests +
heads. The old `uploads`, `reviews`, and `snapshots` tables (and their
stub DAL methods) are deleted.

## Epochs

- One monotonic counter, advanced **only by patch cuts**, and only when
  at least one document changed. Numbers are assigned at cut time, so
  they are consecutive.
- **Patches chain strictly**: the patch for epoch N assumes the
  consumer holds exactly the published state of epoch N−1. Consumers
  apply patches in order with no gaps.
- Diffs run **published-rev → latest-accepted-rev**. If a user uploaded
  revs 4 and 5 between cuts, the patch is diff(3→5); rev 4 is never
  published.
- **Snapshots do not consume epochs.** A snapshot is a materialization
  of the corpus *at* an existing epoch — same number, no chain event.
  Cadence: every 100 epochs (configurable), plus one at epoch 1 so a
  cold-start entry point always exists.

## Artifacts

One logical model for both artifact kinds: **concatenated canonical
sjsonl entries, located by manifest offsets**. No tar. Entry boundaries
are never inferred from content (data lines are author-controlled, so
content-sniffing for control lines is unsound) — boundaries come only
from the manifest.

**Snapshot** (`kind: snapshot`):

- Each entry is a full signed document, individually gzip-compressed;
  members are concatenated. Concatenated gzip members form a valid
  gzip stream, so `gunzip` of the whole artifact yields the readable
  concatenated corpus, while range-capable consumers pluck individual
  members using manifest offsets.
- The stored artifact is split into **chunks**: consecutive slices of
  the member concatenation, published as separate files
  (`snapshot.0`, `snapshot.1`, ...). Splits happen only at member
  boundaries, so an entry never spans chunks and every chunk is
  itself a valid gzip stream.
- Manifest offset/size are **global**: they address the logical
  concatenation of all chunks (compressed, as stored). The manifest
  metadata line carries a **chunk table** — `[{size, hash}, ...]` in
  file order, `hash` being the hex sha256 of the chunk's stored
  bytes — and a consumer maps a global offset to (chunk, local
  offset) with a running sum over the table. A single-chunk snapshot
  is the degenerate one-row table.
- The chunker targets a configurable chunk size (default 256 MiB —
  comfortably under CDN cacheable-object caps, e.g. Cloudflare's
  512 MB, and a sane unit for parallel fetch and retry). The target
  is advisory: an entry larger than the target gets a chunk to
  itself. Chunk hashes let mirrors and consumers verify each chunk
  independently before use; per-document verification still happens
  per entry.
- Entries are ordered newest-first (by head rev received time), so a
  mostly-synced peer's gaps cluster at the front — in the lowest-
  numbered chunks — and its range requests coalesce.
- Per-entry compression sacrifices cross-document redundancy; that is
  the price of addressability, paid only here.

**Patch** (`kind: patch`):

- One **solid gzip stream** over the concatenated entries, capturing
  cross-document redundancy (patches are consumed whole, so
  addressability inside the compressed file is not needed).
- Manifest offset/size address the **decompressed stream**; consumers
  gunzip the whole file and slice entries arithmetically.
- Entries are sjsonl **patch** documents for previously published
  users, or full **doc**s for first-appearance users (no base to diff
  against). Entries are self-describing via their control lines
  (`"sjsonl":"patch"` vs `"sjsonl":"doc"`), so consumers dispatch per
  entry: doc → replace, patch → apply. The publisher may also ship a
  full doc whenever the diff would be larger.
- sjsonl patch headers carry the base document hash, so every
  application is integrity-checked against what the consumer actually
  holds. A mismatch means the consumer has diverged → fall back to
  snapshot.

Format evolution (e.g., zstd, dictionaries) is gated on the manifest's
format-version field.

## Manifests

Manifests are **sjsonl documents signed with the server keypair** and
published independently of their artifacts.

- Metadata line: epoch, artifact kind, format version, created
  timestamp, and the **previous epoch's manifest hash** — manifests
  form a tamper-evident hash chain, so a mirror can prove the epoch
  sequence it holds is the sequence the server published. Snapshot
  manifests additionally carry the chunk table (see Artifacts).
- Entry lines: `{id, rev, hash, offset, size}` per included user.
  Snapshot manifests list the whole corpus; patch manifests list only
  patched users.
- The `hash` field (sjsonl doc hash of the target document) is the
  cross-mirror consistency check: revs are client-asserted, so two
  mirrors can hold different documents both claiming rev N (author
  equivocation). Hash comparison during a routine manifest diff is the
  only way to detect that fork. Fork *resolution* is out of scope;
  detection is not.
- Note: sjsonl hash-sorts lines, so manifest entries are unordered.
  Consumers key by user id.

## Discovery and serving

Publications are **static files on disk, served as static files**
(stdlib file server: range requests, conditional gets, and CDN/S3
compatibility for free; the serving path has no logic):

    /v1/index.json
    /v1/epochs/<N>/manifest
    /v1/epochs/<N>/patch
    /v1/snapshots/<N>/manifest
    /v1/snapshots/<N>/snapshot.<i>   (one per chunk-table row)

`index.json` contains roughly
`{current_epoch, oldest_retained_epoch, snapshot_epochs, server_key}`.

The index is **unsigned**: everything it points to is signed, so
tampering can only point at things that fail verification or withhold
newer epochs. Staleness is mitigated by the created timestamp in each
signed manifest. `server_key` provides trust-on-first-use bootstrap;
consumers pin it thereafter, and serious mirrors exchange keys out of
band.

The legacy `/`, `/checkpoint`, and on-the-fly `/snapshots` endpoints
are deleted.

## Cut mechanics

- In-process ticker, configurable interval, default hourly. A tick with
  no accepted uploads since `published_head` does nothing.
- Cut order: compute diffs → write artifact and manifest to temp paths
  and rename into place → one DB transaction (`epochs` row +
  `published_head` updates) → regenerate `index.json` from the DB.
  A crash leaves either "epoch never happened" or "epoch exists but
  unadvertised"; the next cut regenerates the index, so both states
  self-heal. No partially visible epoch is observable.
- Retention: keep the last 2 snapshots and every patch back to the
  older of them. The catch-up horizon is therefore the oldest retained
  snapshot; consumers older than that bootstrap from a snapshot by
  design. (v1 need not delete anything; this defines what *may* be
  deleted.)

## Server identity

The server ed25519 keypair is generated on first boot into the data
directory (reusing the existing keygen machinery, base64-encoded). The
key **is** the server's identity — the TOFU pin, the manifest signer,
the thing peers trust. Backing up the data directory is backing up the
identity.

## Out of scope

- Abuse handling, quotas, rate limits.
- Fork resolution (detection via manifest hashes is in scope).
- User deletion / tombstones.
- Client-side consumption implementation.
