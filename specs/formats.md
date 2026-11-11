---
title: Catalog Formats
parent: Specifications
published: false
permalink: /specs/formats/
---

# Catalog

## Item IDs
An 'item' will have a `type` fields, and a number of other fields depending on its type. Some fields are considered *primary*, and they are considered essential for identifying an items. Other fields are *secondary*. The `type` field is always primary. And object ID is a hex string computed from the fields as follows:

**TODOS**: 1) Modify this so secondary hash is verbatim field data, since otherwise the would be no way to differentiate small improvements to Items (i.e. "Pulp Fiction" and "Pulp fiction" need to hash differently)  2) Add some more normalization rules like for urls, dates, ???

1. For each primary field that is not empty:
    1. Convert it to lower case.
	2. Trim any leading or trailing whitespace.
	3. Reduce inter-word whitespace to one space (e.g. '  hello  world  ' -> 'hello world')
2. Sort key/value pairs in alphabetical order by key.
3. Form a string by concatenting key & value with a colon, and key-value pairs with two colons.
4. Compute the SHA256 hash of the string. The first 8 hex characters form the prefix of the ID.
5. Repeat steps 1-3 for all fields, primary and secondary.
6. Compute the SHA256 hash of the string. The 8 hex characters 8-15 form the suffix of the ID.
7. Represent the ID as "prefix-suffix" in lowercase hex.

Example:

```
{
  'type': 'movie',
  'title': ' Pulp  Fiction   ',
  'year': 1994,
  'imdb_id': 'tt0110912',
  'tmdb_id': '680-pulp-fiction  ',
  'some_other_id': '  '
}

First string to hash:

title:pulp fiction::type:movie::year:1994

SHA256: f764edb2bc1e77ea89537e4dee13e759f65f269184680691fe323cf54948d79a
        ^^^^^^^^

Second string to hash:

imdb_id:tt0110912::title:pulp fiction::tmdb_id:680-pulp-fiction::type:movie::year:1994
SHA256: d3a79d1cc021d564e4d0d7d980bb268866f82e447dea6acb23c427ef9ca50967
                ^^^^^^^^

ID: f764edb2-c021d564
```


## Hashed fields

**Movies**
- `type` ("movie")
- `title`
- `year`

**Podcasts**
- `type` ("podcast")
- `title`
- `website`

**Books**
- `type` ("book")
- `title`
- `author`

## Predefined fields
Imdb
Tmdb
Rt
Wikipedia
Title
Year




