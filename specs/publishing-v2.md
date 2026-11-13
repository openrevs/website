---
title: Publishing (v2)
parent: Specifications
published: false
permalink: /specs/publishing-v2/
---

# Publishing Plan (v2)

How the server publishes the ratings corpus to clients and peer servers.
Publications are gzipped tar files of sjsonl documents, served as static
files and described by a single `index.json`.

## Channels

A server publishes to one or more **channels**. Channels may, and
usually will, contain overlapping documents, and a server may define
channels for whatever purpose it chooses. Each channel has its own
epoch counter.

Two channel names are predefined:

- **`main`**: the server's primary feed. This is the channel a client
  attaches to by default to pull from that server. What `main` contains
  is up to the server. For example, `main` might hold only documents
  that have been fully scanned and vetted, while a `raw` channel holds
  everything.
- **`direct`**: only the documents uploaded directly to this server. In
  a well-functioning network, documents spread quickly between servers,
  so a server pulling another server's `main` probably already holds
  most of it from other peers. Pulling `direct` instead cuts that
  traffic substantially without missing the documents that enter the
  network through this server.

## Trust

Documents are the unit of trust: each one is signed by its author, and
consumers verify every document they apply. Publications themselves
(the index, snapshots and patches) are not signed. A server or
intermediary can withhold or delay documents, but it cannot forge or
alter one undetected.

## File layout

All files are static and served as-is:

    /v1/
      index.json
      <channel>/
        snapshot-<epoch>_<part>.tar.gz
        patch-<start>-<end>_<part>.tar.gz

Example:

    /v1/
      index.json
      main/
        snapshot-210_1.tar.gz
        snapshot-210_2.tar.gz
        snapshot-230_1.tar.gz
        snapshot-230_2.tar.gz
        patch-210-211_1.tar.gz
        patch-211-212_1.tar.gz
        patch-212-213_1.tar.gz
        patch-213-214_1.tar.gz
        patch-214-215_1.tar.gz
        patch-210-215_1.tar.gz
        patch-210-215_2.tar.gz
      direct/
        ...

### index.json

`index.json` lists every channel and the snapshots and patches available
in it. `created` at the top level is when the index was generated. Each
channel's `epoch` is its current epoch.

```json
{
  "created": "2026-11-12T21:57:19Z",
  "channels": {
    "main": {
      "epoch": 230,
      "snapshots": [
        {"epoch": 210, "parts": 2, "created": "2026-11-10T21:57:19Z"},
        {"epoch": 230, "parts": 2, "created": "2026-11-12T21:57:19Z"}
      ],
      "patches": [
        {"range": [210, 211], "parts": 1, "created": "2026-11-10T22:57:19Z"},
        {"range": [211, 212], "parts": 1, "created": "2026-11-10T23:57:19Z"},
        {"range": [212, 213], "parts": 1, "created": "2026-11-11T00:57:19Z"},
        {"range": [213, 214], "parts": 1, "created": "2026-11-11T01:57:19Z"},
        {"range": [214, 215], "parts": 1, "created": "2026-11-11T02:57:19Z"},
        {"range": [210, 215], "parts": 2, "created": "2026-11-11T02:57:19Z"}
      ]
    },
    "direct": {
      "epoch": 41,
      "snapshots": [],
      "patches": []
    }
  }
}
```

`parts` is the number of files the artifact is split across. Parts are
numbered from 1.

## Archives

Snapshots and patches share one archive format:

- Each part is a complete, independent gzipped tar file. Splits happen
  only at file boundaries, so no entry spans two parts.
- Archives use ustar format and contain only regular files, with no
  directories, symlinks, absolute paths or `..` components. Consumers
  MUST reject any archive that contains anything else.
- Every name in an entry ends in `.sjsonl`, except the reserved control
  files described below. User IDs are lowercase hex, so a control file
  name can never collide with a document entry.

Entry names are advisory: they let a consumer skip entries it already
has without parsing them. The file contents are authoritative, and it is
an error if the user ID or revs in a name don't match the contents.

## Snapshots

A snapshot holds the full, signed sjsonl document of every user in the
channel at that epoch:

    snapshot-<epoch>_<part>.tar.gz

Entries are named:

    <user_id>-<rev>.sjsonl

Sample of `snapshot-210_1.tar.gz`:

    244eac011af63a9080fb074eeab519f04e2de2686035ae4911982d376d32beb8-432.sjsonl
    c40b5005a10cbe5a3d105334f11db40fec185ca70a64670b705c482e84efef62-23.sjsonl

A snapshot does not consume an epoch. It is the state of the channel at
an epoch that already exists.

## Patches

A patch brings a consumer from the channel's state at the start epoch
of `range` to its state at the end epoch:

    patch-<start>-<end>_<part>.tar.gz

It contains one entry for each user whose document changed in that
range:

- **Changed users** get an sjsonl patch from the rev the channel held at
  the start epoch to the rev it holds at the end epoch, named:

      <user_id>-<base_rev>-<target_rev>.sjsonl

  Intermediate revs within the range are never published.
- **Users new to the channel** in that range get a full document, named
  as in snapshots (`<user_id>-<rev>.sjsonl`). The publisher may also
  ship a full document for a changed user whenever it is smaller than
  the patch.

Entries describe themselves through their sjsonl control line (`doc` or
`patch`), so a consumer replaces a doc and applies a patch. The sjsonl
patch header carries the base document hash, so every application is
checked against what the consumer actually holds. A consumer that
doesn't hold the base must get that user's document some other way: a
retained older rev, a patch with a different range, or a snapshot.

Sample of `patch-210-211_1.tar.gz`:

    244eac011af63a9080fb074eeab519f04e2de2686035ae4911982d376d32beb8-430-432.sjsonl
    c40b5005a10cbe5a3d105334f11db40fec185ca70a64670b705c482e84efef62-19-23.sjsonl

### Removals

A document can leave a channel, for example when it fails later
vetting. A patch lists the users present at its start epoch but absent
at its end epoch in a reserved control file in part 1:

    removed.json

```json
["244eac011af63a9080fb074eeab519f04e2de2686035ae4911982d376d32beb8"]
```

Consumers following the channel drop those users from their view of the
channel. A user removed and re-added within the same range appears as an
ordinary entry, not in `removed.json`. Snapshots simply leave removed
users out.

## Patch retention and compaction

Each cut publishes a single-epoch patch, `N-1 → N`. As patches age, the
server compacts them into coarser ranges aligned to fixed epoch
boundaries, so stale consumers can catch up in a few large steps instead
of many small ones.

The alignment intervals are a published convention, which lets
consumers plan ahead. A consumer SHOULD retain each user's rev as of the
most recent aligned boundary, so it still holds the base of a compacted
patch if it falls behind.

To catch up, a consumer repeatedly takes the patch with the largest
range whose start equals its current epoch. If no patch starts there,
it loads the newest snapshot and continues from that snapshot's epoch.

## Cut mechanics

- An in-process ticker cuts each channel on a configurable interval
  (default hourly). A tick with no changes to a channel does nothing for
  that channel, so epochs are consecutive.
- Order: write the archives to temporary paths and rename them into
  place → commit the epoch to the database → regenerate `index.json`
  (also written to a temporary path and renamed). A crash leaves either
  "epoch never happened" or "epoch exists but isn't in the index yet",
  and the next cut fixes both. No partially written epoch is ever
  visible.

## Open questions

- **Compaction intervals.** Which aligned boundaries (for example every
  24 and every 168 epochs), and how long each granularity is kept.
- **Direct uploads already held by relay.** If a document arrives by
  relay and is later uploaded directly, does it belong in `direct`?
- **Per-document fetch.** Is a "fetch by hash" path worth adding for
  consumers whose base doesn't match, or are retained revs and
  snapshots enough?

## Out of scope

- Abuse handling, quotas, rate limits.
- Equivocation detection and fork resolution.
- User deletion across the network (removal from a channel is in
  scope).
- Client-side consumption implementation.
