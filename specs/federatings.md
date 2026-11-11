---
title: Federation Notes
parent: Specifications
published: false
permalink: /specs/federatings/
---

**Just some random, disorganized todos, notes and references**


# Raison d'être
- Great motivation from Maciej, championing old technology and how the Internet allows niche interests to flourish: http://idlewords.com/talks/web_design_first_100_years.htm
- No interest in submiting to a new site.
- What did Netflix or IMDB do with all those ratings. What about the great Netflix algorithms? Try to get arbitrary ratings out.
- Try exporting from these services
- Ratings are a public expression, locked up in silos, used for profit.
- http://mobile.nytimes.com/2008/11/23/magazine/23Netflix-t.html
- Collaborative filtering is good, but so is seeing a single person's rating history, especially when it aligns well with your. e.g. considered being told:  Fred rated "The Godfather Part III" 1 star.  Now what if you also learn:  Fred rated both "The Godfather" and "The Godfather Part II" 5 stars.
- Following an individual user could be interesting, and fun.  You'll never know if you're being followed, and visa-versa.
- Part of saving the web: https://medium.com/matter/the-web-we-have-to-save-2eb1fe15a426
- Reluctant to write reviews because of the effort involved in fear that they'll just disappear someday.
- Open review format should be the container that can contain multiple types of reviews. Each type of review would have it's own schedule and version. The entire container for me it would also have your version.
- Data is really all the same, and any individual website is just a presentation later.
- Systems like IPFS are trying to solve this on a much grander scale, where as I'm trying to provide a specific fix to a specific problem.
- Some systems pride themselves on letting you get your data out, but that implies that your data was at some point in. With what I'm proposing, your data is always out, and various systems can simply use it.
- Want allow rapid innovation on the client and algorithm side.
- Rather than just hoping that the service you use offers and export option, this application will be intrinsically exported all of the time.
- State simplicity as a goal. The average programmer should be able to write a basic client or even server that interacts with the system.
- Looking at the world of open data standards and protocols is daunting, and depressing.
- Future: books, music, TV, online videos, podcasts ([discussion of discovery](https://www.youtube.com/watch?v=Ce85pRpluec&feature=youtu.be&t=1811)), websites. There may be useful correlations between categories. Ratings for goods and services are out of scope.
- Upload (spam, etc.) reports as a separate file?
- Exchange commentary on published works is a durable, searchable way.
- Joe might have great insights on his blog that you'll never find.
- No need to keep up with streams like Twitter and Facebook.
- Whenever I run into another ratings website, my first thought is: here we go again. The website is going to ask you to enter a lot of my information, probably stuff that you've entered 20 times before, and very likely in a few years it will go away. Instead, you should be able to enter your public key and be done
- When I rate a movie or write a review, I'm not writing it _for_ Netflix or IMDB, I'm writing it _about_ the movie.
- there are lots of places to download rating data sets, but they invariably are of the form "data from this for that service or company quote. In this project, I would like to turn that on its side, where every user provides a data set.


# File Format(s)
- Principles
	- Simple
	- Readable
	- Extensible
	- Standardized/machine readable
	- Concise
- UTF8?
- Read about JWT
- Embedded vs external movie definitions
- What about protobuf or capnproto?
- https://eng.uber.com/trip-data-squeeze/
- Store multiple rating sets in a signle document (movies, music).
- If we want rev in the file name, we also need a index file so we don't require a directory listing to find stuff.
- Protobuf JSON, YAML, XML, etc. file that would contain all of a persons movie ratings including:
	- name/nick
	- demographic (m/f, age, country)
	- email
	- UUID
	- web address of this file
	- For each movie:
		- Title
		- Year
		- Viewing
		- Date watched
		- Rating (0-100)
		- Review
		- Spoiler flag
		- Status: “W” wishlist, “A” avoid list
		- Notes
- Internally any thing can be stored like IMDB/TMDB ids or artwork/wikipedia links. But published data should be minimal.
- Standard Naming?
	- http://www.imdb.com/czone/?ref_=nv_cm_cz_2
	- http://www.imdb.com/updates/guide/title_formats
- How to handle different languages? Smart client that will figure it all out.
- Don't include stuff like Likes in official record. Not a popularity contest. Avoid everyone reading the top reviews? Or maybe not... Dunno
- Assumption: there will be accessible databases that the client can reference gives addresses, links or ids.
- how can we can let other sites contribute on a users behalf in a way that is secure? Maybe quasi-self-hosted apps like https://sandstorm.io


# JSON Signing
- Use a modified version of Camlistore’s signing scheme.  https://camlistore.googlesource.com/camlistore/+/master/doc/json-signing/
- Asymmetric authentication is done using Adam Langley’s ed25519 library. Every user will generate a public/private key pair.
- Serialize object to JSON
- Remove trailing whitespace and convert to UNIX line endings "\n"
- JSON must have a “user_id” field containing the users public key in ascii hex format, lower case, without any delimeters
- Remove last paren ‘}’ from string
- Calculate ed25519 signature of this string
- Append a base64 version of the signature to the string like: ,"signature":""}



# File Organization
TBD

# Distribution
TBD

# References
- https://movielens.org/profile/about-your-ratings
- http://letterboxd.com
- http://www.phi-phenomenon.org
- http://web.onetel.com/~hibou/morse/MORSE.html
- https://en.m.wikipedia.org/wiki/Reputation_system
- ftp://ftp.fu-berlin.de/pub/misc/movies/database/diffs/README
- http://archive.org/stream/GuerillaOpenAccessManifesto/Goamjuly2008_djvu.txt
- [Hashing javascript objects](https://github.com/puleos/object-hash/blob/master/index.js)
- https://en.m.wikipedia.org/wiki/Reputation_system
- https://about.radiopublic.com/why-podcasting-still-needs-rss-6a2779e94e96
- https://techcrunch.com/2016/10/09/a-decentralized-web-would-give-power-back-to-the-people-online/
