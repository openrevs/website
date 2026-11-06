# Post-Quantum Signatures

How the formats and publishing pipeline change when signatures move
from Ed25519 to ML-DSA-44. Captured 2026-10-12. Draft.

Prompted by Filippo Valsorda's "Post-Quantum Cryptographic Right
Answers" (https://words.filippo.io/right-answers/). There are no users
and nothing to migrate: sjsonl 0.1 and all dmrs keys target ML-DSA-44
directly. Ed25519 is gone, not deprecated.

## Algorithm

- **ML-DSA-44** (FIPS 204) for every signature: user root keys,
  delegate keys, the server key. Go's stdlib `crypto/mldsa` covers it.
- **No hybrid, no negotiation.** sjsonl 0.1 means ML-DSA-44. There is
  no `alg` field; a future algorithm is a new format version, not an
  option inside this one.
- **Private keys are stored as the 32-byte seed**, never the expanded
  key. The user-facing model in security.md ("save these 32 bytes")
  is unchanged.
- **Every signature uses an ML-DSA context string** for domain
  separation (see Domain separation below).
- No pre-hashing or external-μ. The sjsonl signing message is the
  sorted concatenation of 32-byte line hashes, small enough to sign
  directly.

## The size problem

| | Ed25519 | ML-DSA-44 |
|---|---|---|
| Public key | 32 B | 1,312 B |
| Signature | 64 B | 2,420 B |
| key + sig, hex in a header | 192 chars | 7,464 chars |

Keys and signatures are random bytes and do not compress. Measured
gzip size of a patch entry that changes one rating line:

| Patch entry | gzip size |
|---|---|
| Ed25519 header + line | ~325 B |
| ML-DSA-44 header (key + sig) + line | ~4.5 KB |
| ML-DSA-44 header (sig only) + line | ~3.0 KB |
| No signature material + line | ~100–200 B |

In a solid patch stream the JSON around the keys compresses away
further, but the random bytes don't, so the real ratio is worse than
these standalone numbers suggest.

Where signature material appears today:

| Place | Frequency | Verdict |
|---|---|---|
| sjsonl header in each **patch entry** | every changed user, every cut | **The problem.** Fixed by changes 1 and 2. |
| sjsonl header in each snapshot doc | once per user per snapshot | Acceptable: ~3.7 KB fixed per user. |
| Authority line (root sig, delegate keys) | once per grant change | Acceptable: unchanged lines aren't re-sent in patches. |
| Manifest signature | once per epoch | Negligible. |
| Upload to the server | once per revision | Negligible. |

## Change 1: send each public key once

Today every sjsonl header carries the full `key`, including every patch
header, though the consumer already holds the key from the base
document.

- **`doc` headers keep `key`.** A standalone document must verify on
  its own.
- **`patch` headers replace `key` with `kid`**, the hex SHA-256 of the
  signer's public key. The consumer resolves `kid` to a key it already
  holds. The sjsonl default resolver is the base document's `key`;
  applications may supply others.
- **dmrs resolves `kid` against the root key and the delegate keys in
  the current authority line.** Grants keep full delegate public keys:
  they are lines in the document, so each one travels once, when the
  grant is added.
- An unresolvable `kid` is a verification failure, handled like a bad
  signature: the consumer has diverged and falls back to a snapshot.

This saves ~1.3 KB of random bytes per patch entry.

## Change 2: move signatures out of the patch stream

This is the article's point about transparency logs letting you spend
signatures less often. The manifest chain is already most of a
transparency log:

- The server verifies every signature at ingest.
- Each manifest commits to every published target document hash and
  is signed and hash-chained.
- delegation.md already defines a **default verification depth** that
  trusts the signed, fork-detectable manifest chain.

So patches stop carrying author signatures:

- **Patch entries carry no `sig`.** An sjsonl patch without `sig` is an
  *unsigned patch*: applying it yields a line set whose document hash
  must equal the patch's `target`, and `target` is authoritative.
  Consumers check that hash against the manifest entry's `hash`.
- **Each epoch publishes a signature file next to the patch:**

      /v1/epochs/<N>/sigs

  One line per patched user, `{id, target, kid, sig}`, gzip-compressed.
  It's covered by the manifest: the metadata line carries its hash and
  size.
- **Full verifiers and mirrors fetch `sigs`**, recombine with the
  patched documents, and hold fully signed documents they can re-serve.
  Default consumers skip it.
- **Snapshots keep full signed documents.** Bootstrap is end-to-end
  verifiable without the chain, and the ~3.7 KB per user is paid once
  per snapshot, not per change.
- **`sigs` files are retained like manifests (forever).** They're the
  only proof of authorship for revisions that were published in a
  patch and superseded before the next snapshot. They're ~2.5 KB per
  published revision; patch artifacts are still pruned under the
  existing retention rule.

The patch stream returns to roughly Ed25519-era size.

**Trade-off.** A default consumer's guarantee changes from "the author
signed this" to "the server verified the author's signature and
committed to the result in a chain that mirrors compare." A dishonest
server could publish a document the author never signed, but it would
have to put the target hash in a signed manifest. Any full verifier
holding the `sigs` file then exposes it, and the manifest is permanent
evidence against the server. This is the same trust delegation.md
already relies on for acceptance time.

### Full-length document hashes

Once the document hash is a commitment that substitutes for a
signature, 128 bits (64-bit collision resistance) is too short. The
author is exactly the party equivocation detection guards against, and
they choose the content, so they can search for a collision. The
document hash becomes the **full 32-byte SHA-256** of the signing
message, everywhere it appears: sjsonl `base`/`target`, the manifest
`hash` field, and blob storage keys (`docs/<hash[:2]>/<hash>`).

## Domain separation

Today the root key signs both sjsonl documents and authority payloads,
and nothing in the signature distinguishes the two. No practical
confusion exists now: one message is a concatenation of binary hashes,
the other is JSON text. But that separation is an accident of the
formats, not a property anyone guarantees, and it would break silently
if either format changed. ML-DSA's context string makes it explicit at
no cost.

| Signature | Signer | Context string |
|---|---|---|
| sjsonl document (incl. manifests) | author, delegate, or server | `sjsonl-0.1-doc` |
| dmrs authority payload | root | `dmrs-authority` |

The server key only signs manifests, which are sjsonl documents, so it
needs no context of its own. A future sjsonl API may let applications
supply their own context. It isn't needed yet.

## User IDs

The ID is `SHA256(root pubkey)[:8]`, 16 hex digits. With no users, now
is the time to fix two things:

- 64 bits is short for "forever" data. A targeted preimage (a key whose
  ID matches a victim's) costs ~2^64 hashes: expensive today, not
  durably safe. Under delegation the owner claim binds by ID, so a
  matching ID is the attack.
- **Recommendation:** keep the 16-hex ID as a display and lookup
  handle, but bind ownership to the full key hash. The metadata line's
  owner claim and the authority payload's `id` carry the full SHA-256
  of the root public key; the short ID is derived from it. Short-ID
  collisions are then a lookup ambiguity, not an authority bypass.

## Unchanged

- **Authenticating exact bytes.** Line hashes cover each line's stored
  bytes (with only leading and trailing whitespace trimmed), and the
  authority payload is an opaque string. That's already the article's
  "authenticate verbatim bytes" rule.
- **Hex encoding.** After gzip, hex costs ~10% over raw binary.
  Switching to base64 isn't worth the inconsistency.
- **Manifest chain, epochs, snapshots, cut mechanics.** Only the
  additions above.
- **Server key.** One ML-DSA-44 keypair generated on first boot and
  stored as a seed. TOFU pinning via `index.json` is unchanged; the
  pinned key is 1,312 bytes, which is fine.

## Docs and code to update

- sjsonl SPEC: ML-DSA-44, context string, 32-byte document hash, `kid`
  in patch headers, unsigned patches with authoritative `target`.
- security.md: the Algorithms and User IDs sections.
- publishing.md: `sigs` artifact, manifest metadata fields, full-length
  hashes, retention of `sigs`, key generation.
- delegation.md: full-hash owner binding, `kid` resolution via grants,
  `dmrs-authority` context.
- Code: keygen and seed storage, sjsonl sign/verify, ingest
  verification.

## Open questions

- Should `sigs` also be generated for snapshot epochs, so a mirror can
  rebuild a snapshot without signatures and attach them separately?
  (Probably unnecessary: snapshots carry them inline.)
- Is the `sigs` file per epoch or batched across epochs for small
  cuts? Per epoch keeps the one-epoch-one-set-of-files model.
