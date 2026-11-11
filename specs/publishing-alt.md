---
title: Publishing (Alternative)
parent: Specifications
published: false
permalink: /specs/publishing-alt/
---

# Publishing Plan — Alternative: Origin Feeds

An alternative to [Publishing]({{ site.baseurl }}/specs/publishing/), drafted 2026-11-09.
Not yet reviewed. Upload handling, storage and the signed manifest
chain carry over mostly unchanged; how artifacts are published and how
they reach consumers is redesigned.

## Motivation

`publishing.md` has one server publishing its whole corpus to its
consumers. The harder case is a consumer, server or client, that pulls
from **many** upstream servers. In a healthy network, an update reaches
every server soon after it is uploaded. Once you've pulled it from one
upstream, every other upstream's patch that includes it is redundant.
If each server publishes everything it holds, a consumer with N
upstreams downloads most updates N times. Each upstream's few unique
documents are mixed in with ones the consumer already has, so it
can't get them without the rest.

The fix rests on one observation: **each update enters the network at
exactly one server**, the one the author uploaded it to. If every
server publishes only what was uploaded to it directly, each update
appears in about one place. Pulling every server's direct-upload
publications gives a consumer each update once, with almost no
duplication.

## Concepts

- **Origin server**: the server a document was uploaded to directly.
- **Origin feed**: a server's publication of its own direct uploads,
  and nothing else. Each server has exactly one origin feed, identified
  by the server's public key.
- **Relayed document**: a document a server got from another server's
  feed instead of from a direct upload. Relayed documents are stored
  and served by hash, but **never** added to the server's own origin
  feed.
- **Mirror**: a verbatim copy of another server's origin feed,
  republished by a server that follows it. Manifests are signed by the
  origin server, so a mirror can be verified exactly as if it came from
  the origin.
- **Cursor**: a consumer's position in one feed (its last applied
  epoch). A consumer's sync state is a map of cursors, one per feed:

      { <keyA>: 812, <keyB>: 40, <keyC>: 1290 }

## Ingest

### Direct uploads

The upload handler works the same as before:

1. Verify the document: valid sjsonl signature, and the user ID
   matches the signing key.
2. Check that the asserted rev is strictly greater than the highest
   rev held for that user, **from any source**.
3. Persist the document and mark its source as `direct`.
4. Return `200` accepted, `400` invalid, or `409` stale rev, with the
   reason in a JSON body.

If the server already holds a document with this exact hash (it
arrived first by relay), return `200` and don't mark it direct. The
document is already in the network, so publishing it again would only
create the duplication this design is meant to avoid.

### Relayed documents

Documents applied from followed feeds go through the same checks (1)
and (2), are persisted with their source feed key, and never enter the
local origin feed. A relayed document whose rev is not greater than
what the server holds is ignored, not treated as an error. Applying
updates is idempotent: you can't apply the same hash twice, and older
revs are skipped.

Rev handling is unchanged: revs are asserted by the client and appear
inside the signed document, and the only thing the server enforces is
strict monotonicity per user.

## Storage

Documents are stored as before, by sjsonl doc hash:

    docs/<hash[:2]>/<hash>

The database tracks metadata:

- `documents(userid, rev, hash, size, received_time, source)` —
  `source` is `direct` or the key of the feed it arrived through. Unique
  on `(userid, rev)`.
- `origin_epochs(epoch, manifest_hash, created)` — this server's own
  feed ledger.
- `origin_head(userid, rev, hash)` — what this server's origin feed last
  shipped for each user.
- `feeds(origin_key, cursor, mirrored, last_fetched)` — feeds this
  server follows, its cursor in each, and whether it republishes them.
- `snapshots(id, created, manifest_hash)`.

## Origin feeds

### Epochs

- Each origin feed has its own epoch counter. There is no global epoch.
- The counter advances only on a cut that includes at least one new
  direct upload, so epochs are consecutive.
- Each epoch's manifest includes the hash of the previous epoch's
  manifest. The feed is a tamper-evident hash chain, and it stays
  verifiable when fetched from a mirror.

### Patch entries

The patch for epoch N contains one entry per user with a new direct
upload since the last cut:

- **Target**: the latest direct rev for that user. Intermediate direct
  revs since the last cut are never published, as before.
- **Base**: the rev this server held for that user just before the
  target arrived, **from any source**. That is the rev consumers most
  likely hold too. The entry is an sjsonl patch from base to target,
  or a full doc if there is no base or a full doc is smaller.

Each patch entry carries its own `base` hash, so entries don't depend
on each other: a consumer applies a patch entry if it holds that exact
base, and otherwise fetches the target document by hash (see
[Documents by hash](#documents-by-hash)). The case this catches is an
author uploading to more than one server (rev 5 to A, rev 6 to B).
B's patch for rev 6 is based on whatever B held, which may not be what
the consumer holds.

### Artifact format

A patch artifact is a **single gzip stream** of JSONL **envelope**
lines, one per entry:

    {"id":"<userid>","rev":6,"hash":"<target doc hash>","entry":"<sjsonl text>"}

`entry` is the full sjsonl patch or doc, header line included, encoded
as a JSON string. The envelope frames the entries, so artifacts
contain their own boundaries: there are no manifest offsets, and
`gunzip | while read line` is a complete reader. The escaping overhead
compresses to almost nothing.

Consumers MUST check that each envelope's `id`, `rev` and `hash` match
the manifest, and that the decoded entry produces a document with that
hash.

### Manifests

Each epoch has a manifest, an sjsonl document signed with the origin
server's key, published separately from the artifact.

- Metadata line: `origin` (server key), `epoch`, `prev` (previous
  manifest hash), `created`, `format` (format version), `artifact`
  (sha256 of the stored artifact bytes), `size`.
- Entry lines: `{id, rev, hash, base}` per patched user. `base` is the
  base doc hash, or null for a full doc.

Because the manifest signs the artifact hash, a mirror cannot alter
the artifact undetected. Because the manifest lists every entry's
`hash`, a consumer knows which documents an epoch delivers before
downloading the artifact.

### Rollups (optional)

When a consumer has been away a long time, it may have many small
epochs to catch up on in a feed. A feed MAY also publish rollups over
fixed, aligned ranges, for example every 24 epochs. A rollup is a
patch from each user's state at the start of the range to their state
at the end. It is built and formatted exactly like a patch artifact,
with `from` and `to` in its manifest metadata. Rollups never replace
epoch patches; consumers can always fall back to the epoch chain.

Leave rollups out of v1 unless catch-up request counts turn out to be
a problem. Origin feeds should be small.

## Mirroring

A server that follows a feed MAY mirror it: after verifying each
epoch's manifest and artifact, it republishes both **byte for byte**
under that feed's path. It never re-signs or re-encodes them.

- **Availability**: if the origin is offline, its feed can still be
  fetched and verified from any mirror.
- **Discovery**: a server's index lists the feeds it mirrors, so a
  consumer learns about servers it didn't know of. Following mirrors
  leads, step by step, to the whole network.
- **No merging**: a server never combines other feeds into its own.
  There is one feed per origin, wherever it is fetched from.

A mirror can retain a different range of epochs from the origin, and
its index reports the range it actually holds.

## Documents by hash

Every document the server holds, direct or relayed, is served at:

    /v1/docs/<hash>

as the full signed sjsonl doc. All servers serve the same bytes for the
same hash, so a consumer can fetch a document from any server. This is
the fallback when a patch entry's base doesn't match what the consumer
holds, and it lets clients fetch specific users without syncing
anything.

## Snapshots

Snapshots are for cold start: a new consumer wants everything, so
duplication across feeds doesn't matter here.

- A snapshot is the server's whole current corpus, one envelope line
  per user's latest document (always a full doc), together with the
  **cursor map** at the moment it was taken. A consumer that loads a
  snapshot starts each feed from the cursor the snapshot records.
- Envelope lines are written as one gzip stream, split into files at
  envelope boundaries once a target size is reached (default 256 MiB,
  for CDN object limits). Each file is an independent gzip stream.
- A signed snapshot manifest lists the files in order, each with its
  size and sha256, plus the cursor map. Per-user entries are not
  listed: the envelopes carry them, and each document verifies on its
  own.
- Cadence is configurable (for example daily), plus one at first boot.

Some documents may be both in the snapshot and in a feed after the
recorded cursor, because they were relayed in before the snapshot.
Applying them again is harmless, since applying updates is idempotent.

## Consumer sync

For each followed feed, from any server that has it (the origin or a
mirror):

1. Read that server's `index.json` to find the feed's current epoch.
2. Fetch manifests from `cursor+1` to current. Verify each signature
   against the pinned origin key, and verify the `prev` chain.
3. For each epoch, if any listed `hash` is not held, download the
   artifact, check it against the manifest's `artifact` hash, and
   apply each needed entry: doc → store, patch → apply if the base
   matches, otherwise fetch `/v1/docs/<hash>`.
4. Advance the cursor.

A consumer MAY skip downloading an artifact when it already holds
every hash the manifest lists. Fetching only a few documents by hash
instead of the whole artifact is the consumer's choice. In origin
feeds that should rarely matter, since nearly every entry is new.

Equivocation is detected the same way as before, but across feeds:
two documents with the same `(id, rev)` and different hashes. The
signal can appear in two origin feeds, or in a feed and a direct
upload. Detecting it is in scope; resolving it is not.

## Discovery and serving

Everything is static files. All paths use the origin key as lowercase
hex, because standard base64 contains `/` and `+`:

    /v1/index.json
    /v1/feeds/<originhex>/<N>/manifest
    /v1/feeds/<originhex>/<N>/patch
    /v1/snapshots/<id>/manifest
    /v1/snapshots/<id>/snapshot.<i>
    /v1/docs/<hash>

The server's own origin feed is simply the entry under its own key.

`index.json` (unsigned, as before) contains roughly:

    {
      "server_key": "<base64>",
      "feeds": [
        {"origin": "<base64>", "own": true,  "oldest": 1,   "current": 812},
        {"origin": "<base64>", "own": false, "oldest": 600, "current": 1290}
      ],
      "snapshots": [{"id": "...", "created": "..."}],
      "peers": [{"url": "https://...", "key": "<base64>"}]
    }

`peers` is optional, a hint toward where origins live. Trust still
comes from keys, not URLs: everything the index points to is signed,
so a tampered index can only point to things that fail verification,
or hide newer epochs. Origin keys are trusted on first use and pinned
after that, as with `server_key` before.

## Cut mechanics

The process is unchanged, except that a cut only ever covers direct
uploads:

- In-process ticker, default hourly. A tick with no direct uploads
  since `origin_head` does nothing.
- Order: compute entries → write the artifact and manifest to temp
  paths and rename them into place → one DB transaction
  (`origin_epochs` row + `origin_head` updates) → regenerate
  `index.json`. A crash leaves either "epoch never happened" or "epoch
  exists but isn't in the index yet", and both resolve on the next cut.
- Mirroring and feed pulls run on their own schedule and use the same
  temp-file-and-rename writes. The index is regenerated after them.

## Retention

- Own feed: keep every epoch back to the oldest retained snapshot's
  cursor for this feed. Older epochs MAY be deleted.
- Mirrored feeds: keep at least as far back as the server's own oldest
  retained snapshot's cursor for that feed, so that loading a snapshot
  and then catching up from this server always works.
- Snapshots: keep the last 2.
- Documents by hash: keep any document reachable from a retained
  snapshot or epoch, plus each user's latest. Garbage collection is a
  mark-and-sweep from those roots, as before.

## Server identity

Unchanged: an ed25519 keypair generated into the data directory on
first boot. The key is the server's identity: it names the origin feed,
signs manifests, and is what peers pin. It is base64-encoded per the
current sjsonl spec, and lowercase hex in URL paths.

## Differences from publishing.md

| publishing.md | This alternative |
|---|---|
| One feed of everything the server holds | One origin feed of direct uploads only, plus verbatim mirrors of other feeds |
| One global epoch counter | One epoch counter per origin, and a cursor map per consumer |
| Patches chained strictly; base must be epoch N−1 state | Feed epochs still chained; each patch entry is checked only against its own `base` hash |
| Manifest offsets locate entries | Envelope lines locate entries; artifact hash in the manifest |
| Snapshot: per-entry gzip, global offsets, chunk table, newest-first, range requests | Snapshot: envelope lines in a gzip stream split into size-capped files, plus a cursor map |
| No per-document fetch | `/v1/docs/<hash>` on every server |
| Index points to one epoch sequence | Index lists own and mirrored feeds, and optional peers |

Removed entirely: range requests, global offsets, separately
compressed snapshot entries, newest-first ordering, and snapshots tied
to epoch numbers.

## Open questions

- **Document and patch sizes.** If documents are a few KB, consumers
  could skip patches and fetch full docs by hash, which would simplify
  things further. Real numbers would settle this.
- **Which feeds to mirror.** All followed feeds? Only up to some size?
  Mirroring is cheap (static copies), but storage adds up across many
  origins.
- **Withholding.** An origin can delay or drop entries in its own feed,
  and mirrors can only repeat what it published. Detection would mean
  comparing what different servers actually received. Not addressed
  here.
- **A doc both uploaded directly and relayed.** The rule above (if
  the hash is already held, don't publish it again) assumes the earlier
  copy will reach every consumer. Is that true for consumers that
  follow only this server?
- **Feeds for servers with no direct uploads.** Pure mirrors have an
  empty origin feed. Should they still list it in the index, or leave
  it out?
- **Rollups.** Are they needed at all?

## Out of scope

- Abuse handling, quotas, rate limits.
- Fork resolution (detection is in scope).
- User deletion / tombstones.
- Withholding detection.
- Client-side consumption implementation.
