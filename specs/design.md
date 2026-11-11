---
title: Catalog IDs
parent: Specifications
published: false
permalink: /specs/design/
---

Catalog IDs
===========

# Article identification
One of the trickiest parts of the design will be how to positively identify an article. There is no central database, yet a collection
of independently created files should be relatable. For the most part this means some heavy lifting by the client to decide whether two
works are the same thing, but there are some specs that could make this easier:

- reusing existing definition
- naming conventions
- supporting references
- designation of primary fields
- consistent object hashing schema

TBD: Embedded vs external

## Naming conventions
Individuals will be adding articles unless they're already found in other containers. There's a lot to be gained in the article is added
is a predictable way. The spec could offer guidance for how to name things for each category.
	- http://www.imdb.com/czone/?ref_=nv_cm_cz_2
	- http://www.imdb.com/updates/guide/title_formats

## Supporting references
It may not be sufficient to provide just a title and year (using movies as an example). Additional references, such as ids within other
database, could be included as supporting information. Examples might be IMDB, TMDB, Wikipedia. There are tradeoffs here. For any article,
the ideal is a correct set of information to positively identify it, without being too specific. A "movie" of title "Pulp Fiction" released in 1994 is probably sufficiently
specific. Other articles should have more identifying information. 
A book's ISBN identifies the article, but there are many ISBNs for a single title so it isn't a good trait. HOW TO DECIDE????

For all fields we will trim and the leading and trailing spaces, remove double spaces in between the words, and lowercase everything.

For movies, the original language title will be used just as it is on IMDb.
