# Security

Ratings and reviews are intended to be public, unencrypted and published widely. That's the whole
point of this projects. But there are still security concerns, such as anonymity and authenticity.
The file format is design to help in this regard, but I was to get out there right now: *This is
design is cooked up by someone not terribly skilled in the art (me), and I would appreciate feedback
on how to make it better.*

## Anonymity

There are no particular traits of the file format that reveals, or protects, the anonymity of the
author. All of the user identification fields, such as email, name, website, etc. are completely
optional. A person may usefully particate with just a public key, which reveals nothing about their
identity. It is most important that client applications make clear to users that and information the
provide will be published effectively forever. Once a ratings file with my email is published,
subsequent revisions may remove the email but nothing will remove the old revisions from those
systems that might want to store them. Let directly, people should be made aware that ratings,
review dates, review notes and other information could possibly be correlated with other data on the
internet.

These warnings should be made clear to users at the start, and when they're about to enter
personally identifying information.

## Authenticity

It is important that one cannot publish as other user. A ratings set should be verifiable againsts a
published public key. This key needn't exist outside of the ratings system, thought it may. If a NY
Times movie critic has published that their user ID is 4567, anyone should be able to verify that a
ratings set by 4567 is authentic. All data shared with servers and client will be verified against
the public key that is embedded within it. Data that fails this verification should not be rejected.

### Alternate public keys

There may be occasions where a users want another system to publish ratings sets for them. For
example, it may be convenient for a website about movies to access a user's ratings *and* publish
updates to them. But publishing a rating set requires signing, which requires access to the private
key. Users should never provide their private key to anyone, so a workaround is needed. The current
proposal is for the third-party to create a new keypair, and the user to publish a list of IDs that
should considered as their own. If a rating set from ID `4567` includes a `source_id: 12345` field,
clients should check the latest version of `1234` list `4567` into the `authorized_ids` sections.

## Algorithms

The [Ed25519](https://ed25519.cr.yp.to) was chosen for message signatures. It is consideredfast,
secure, and has the desireable property of short public and verification keys. Using 32 bytes of
random data, which the users should save for safekeeping, a public and private key are generated.
All ratings sets will include the public key and will be signed.

### User IDs

Though Ed25519 generates relatively compact public keys, they are still too long for easy entry or
display. As alternative ID is derived from the public key by hashing with SHA256 and truncating it
the first 8 bytes, as 16 hex digits:

For public key `49f7f5a73fc25c0454d06e2c8b31c31b8f78003970731bce84218e8b836c9182`, the ID will be:
`5656b40d536048f7`.
