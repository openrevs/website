---
title: Delegation
parent: Specifications
published: false
permalink: /specs/delegation/
---

# Delegation Plan

How a user authorizes third-party keys to publish revisions of their
ratings document without ever sharing the root private key.
Captured 2026-08-13; revised after review — single-document scheme
adopted. Draft.

## Overview

A user's identity is their root Ed25519 keypair; the user id derives
from the root public key. Delegation lets another party (e.g. a movie
site the user trusts) sign and publish new revisions of the user's
ratings document with a key of its own. The user grants and revokes
this authority unilaterally; the delegate never holds the root key.

The mechanism is a single root-signed **authority line** embedded in
the ratings document itself, carrying the current set of delegate
grants and a sequence number. One user remains one document, and the
publishing pipeline is unchanged.

## The authority line

A ratings document contains at most one authority line — a data line
whose payload is signed by the root key:

```json
{"revs":"authority","auth":"{\"id\":\"5656b40d536048f7991d60b295214e4070a7b1734bdcd66159417d1b82115867\",\"seq\":2,\"grants\":[{\"key\":\"<delegate pubkey>\",\"label\":\"netflix\",\"not_before\":\"2026-08-01T00:00:00Z\",\"expires\":\"2027-02-01T00:00:00Z\"}]}","sig":"<root sig over the exact auth bytes>"}
```

- `auth` embeds the payload as an opaque JSON string, so the inner
  signature is over exact bytes and no canonicalization scheme is
  needed. The escaping hurts readability — an accepted wart.
- The payload carries the owner id, a sequence number `seq`, and the
  **current grant set**. Each grant has the delegate public key, a
  human label, required `expires`, and optional `not_before` (default:
  no lower bound). Clients should default to modest lifetimes and
  renew.
- Grant scope is coarse: a grant means "may publish ratings-document
  revisions", full stop. Field-level scoping (e.g. "may only touch
  entries it created") is not offered — the line-set model gives
  whole-document signing authority to whoever signs, and finer scope
  would require every verifier to diff revisions. No granularity is
  promised that cannot be verified.
- This is a revs-layer construct only. To sjsonl it is an ordinary
  data line; the sjsonl spec is untouched.

Rules:

- **`seq` strictly increases** with each new payload. The server and
  chain-following consumers track the high-water `seq` per user; it
  never resets, even if the line later disappears from the document.
  A replayed older line is rejected exactly like a stale rev.
- **Delegate-signed revisions must carry the current (highest-seq)
  authority line.** Root-signed revisions may update it (a new payload
  with `seq`+1), carry it unchanged, or omit it — omission asserts
  nothing and does not reset the counter. A user who fully retires
  delegation ends up with a clean, line-free document again.

## Why the current set, not a history log

An earlier two-document draft kept an append-only grant/revoke log,
because there the authority state and the ratings head were not
atomically bound: a cold-start consumer verifying an old
delegate-signed ratings head had only the *current* authority document
to check against, so it had to carry history.

In the single-document scheme every revision embeds its
contemporaneous authority state. Verification is self-contained per
revision: the signer must appear in *that revision's own* authority
line with a window covering *that revision's* acceptance time. History
still exists, distributed through the rev chain — a full-replay
verifier checks each historical revision against its own embedded
line. And revocation is inherently a new head (the root must publish a
revision to revoke), so there is no reachable state in which the head
is delegate-signed and that delegate is revoked. Nothing ever consults
a past authority state that is not already embedded where it is
needed. The current set suffices.

## Grant and revocation flows

**Grant.** The delegate generates a keypair (one per user,
recommended) and gives the user its public key. The user's client
signs a new authority payload (`seq`+1) adding the grant. Because the
line is self-certifying, granting requires no publish by the user: the
signed line is handed to the delegate out of band, and the delegate
embeds it in the next revision it publishes. (The user's client may
also publish a revision carrying the new line itself; both are valid.)

**Revoke.** The root publishes a revision whose authority line is a
new payload (`seq`+1) without the grant — possibly the revision's only
change (a real content change, so the "bump rev only when content
changed" guidance holds). From that moment the server rejects uploads
signed by the revoked key. A revoked delegate replaying its old line
is a `seq` regression, rejected like a stale rev.

Revocation is not retroactive. Revisions accepted during the grant
window remain valid — see Time below. If a delegate misbehaved, the
root publishes a cleanup revision; the root can always sign a higher
rev, so the root always wins.

**Publish (delegate).** Fetch the user's current document, apply
changes, bump the rev, carry the authority line forward, sign with the
delegate key, upload. A concurrent-writer race (root and delegate, or
two delegates) surfaces as the existing `409` stale-rev response; the
loser re-fetches, rebases, retries. No coordination protocol is
needed.

## Verification

### Ingest

For an uploaded document whose metadata line claims owner id U, signed
by header key K:

1. The sjsonl signature must verify (unchanged).
2. If K derives to U (today's check): accept. The revision may carry a
   new authority payload, which must be root-signed for U with
   `seq` greater than the high-water mark.
3. Otherwise the document must contain an authority line whose payload
   verifies against U's root key, with `seq` ≥ the high-water mark
   (equal: the current line; greater: a delegate delivering a fresh
   root-signed line, the out-of-band grant flow), and whose grant set
   contains K, active at ingest time (server wall clock).
4. Rev monotonicity per user (unchanged).

One invariant loosens: today the user id *derives from* the signing
key. Under delegation the document must *claim* its owner id in the
signed metadata line, and the authority check binds the claim.
Delegates should use a distinct keypair per user (cheap, limits blast
radius), but the owner claim is what disambiguates, so a shared
delegate key is not unsound.

### Consumers

A revision of user U's document signed by key K is legitimate iff:

- K derives to U, or
- the revision's own authority line grants K with a validity window
  containing the revision's **acceptance time** (below).

Chain-following consumers additionally enforce `seq` monotonicity
across revisions as defense in depth; a regression implies a dishonest
or corrupted feed — a divergence event like any other, resolved by
falling back to a snapshot.

### Time

Expiry needs a clock, and signed documents carry no trusted time. The
rule: **a grant authorizes publication events, not perpetual data.** A
revision accepted while the grant was live remains valid forever;
expiry and revocation only stop *new* revisions. (The code-signing
timestamping model. Data does not rot when a partnership ends.)

The time oracle is the manifest chain. Each manifest carries a
server-signed created timestamp, and manifests are hash-chained and
cross-mirror comparable. A revision's acceptance time is the timestamp
of the manifest of the epoch that first published it. Verification:
that timestamp must fall inside the grant's window per the revision's
embedded authority line.

Two verification depths follow:

- **Default:** trust the signed, fork-detectable manifest chain for
  the acceptance fact. Cheap; what ordinary consumers do.
- **Full replay:** walk the retained manifest chain and confirm each
  revision's first appearance against its embedded authority line.

A server colluding with an expired or revoked delegate would have to
publish a manifest whose timestamp or ordering contradicts the chain
other mirrors hold — the same equivocation the manifest hash chain
already detects.

## Changes to the publishing pipeline

None structural — no new document kinds, no schema keying changes, no
manifest entry changes for patches, no ordering rules. Two additions,
both independently motivated:

- **Manifests are retained forever.** They are tiny relative to
  artifacts, and the retention policy already prunes only artifacts.
  The manifest chain is the permanent acceptance ledger the time rule
  depends on.
- Snapshot manifest entries record **`since`**: the epoch at which the
  entry's current rev was first published. A snapshot-bootstrapped
  consumer then verifies a delegate-signed head without walking the
  chain to find its acceptance epoch. (`since` is server-asserted but
  signed, and checkable against the retained chain.)

Ingest gains the authority checks above, including parsing the
authority line and tracking the high-water `seq` per user (one small
column next to the existing per-user rev tracking).

## Threat review

A rogue or compromised delegate can:

- Publish garbage ratings revisions until revoked (recoverable via a
  root cleanup revision).
- Burn rev numbers (harmless beyond tiny patches).

It cannot:

- Forge or alter an authority payload (root-signed).
- Extend its own expiry, grant other keys, or replay a superseded
  authority line (`seq` regression).
- Impersonate any other user (the authority check binds the owner
  claim).

A malicious server can delay or withhold a revocation revision — the
same withholding power it already has over any document — bounded and
detectable by the user watching the public feed and by manifest-chain
comparison across mirrors.

## Rejected alternatives

**Naive embedded grant certificates.** Grants as self-certifying lines
*without* a sequence number: revocation cannot work, because a
certificate once issued is held by the delegate forever, and a
delegate signing the document can omit revocation lines and re-add old
grants. The `seq` high-water mark, enforced by the already-stateful
pipeline, is what closes this hole.

**Two-document scheme.** A separate per-user, root-signed "authority
document" holding an append-only grant/revoke log, alongside the
ratings document. Clean trust story (the delegate can never author the
authority stream, so nothing is replayable and no inner signatures are
needed), and it would be the natural home for future root-only
material. Rejected because the cold-start trust model turns out to be
*equivalent* — both schemes lean on the manifest chain for acceptance
time, and a colluding server can serve a stale authority document as
easily as a stale authority line — while the costs are not: it breaks
the one-user-one-document invariant, opens the door to N document
kinds, and forces pipeline changes throughout (`(userid, kind)`
keying, `kind` in manifest entries, authority-before-ratings ordering
within an epoch, same-epoch race semantics). The single-document
scheme buys all of that back for the price of one inner-signed line
and content-level ingest validation.

**Delegate-owned streams.** The earlier sketch in security.md
(`authorized_ids` / `source_id`): delegates publish their *own*
documents under their own ids, tagged with the owner's id, and the
owner's document blesses those ids; consumers union the streams. Real
virtues — no rev races, and revocation retroactively de-attributes
everything from a rogue source. Rejected because it fragments the
profile ("get user U's ratings" becomes an N-document join), forces
every consumer to implement merge-precedence for conflicting ratings
of the same title, and multiplies corpus document count. The root's
ability to publish a cleanup revision recovers most of the
retroactive-de-attribution benefit.

## Out of scope

- Root key rotation and recovery (likely more authority-payload
  material; separate design).
- Field-level grant scopes.
- Abuse handling and quotas for delegates (shared with the general
  abuse story).
- Fork resolution (detection unchanged, via manifest hashes).
