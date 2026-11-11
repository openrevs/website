---
title: Motivation
parent: Specifications
published: false
permalink: /specs/motivation/
---

# It was 20 years ago today...
In 1996 I was adding movie ratings to a website called Eachmovie and it was magic. Given a list of movies, I would rate them 1-5 stars. My reward was receiving predictions on what else I might like, based on thousands of others' ratings. The recommendations were good, and the concept (collaborative filtering) seemed ripe for explosive growth as everyone flocked to the internet. Recommendations _did_ flourish, but not Eachmovie. It was shutdown in 1997?. They were kind enough to
make the ratings available for research, but today one has to dig to find them.

In the years that followed, many a site would ask me to rate those same movies. Lots of those sites also went under, or I went elsewhere. We probably read peak movie-ratings attention during the Netflix Prize competition. This was certainly exciting stuff that I followed very closely, but as far as I can tell it resulted in published research and some prize money. Netflix acknowledged not even using the results, and in my experience their recommendations are heavily weight with factor besides how much I'd like to watch the movie. And in predictable fashion, the massive public ratings set is no longer distributed, and one must search the corners of bittorrent to find it.

There are fairly stable and respectable ratings outlets, such as MovieLens and Criticker (both of which I use), and there are always newcomers in the space. But all of these suffer from the same fundamental flaws:

- if a site goes away, so does the data (most likely)
- users are reentering the same data for every site

When I rate "Pulp Fiction" on Netflix, I'm rating the movie, full stop. This is not a rating _for_ Netflix, it's my assessment of the movie for whoever cares. During the Netflix Prize, there was some excitement when someone correlated Netflix data with IMDB data and identified the user within the anonymized Netflix data. That got me thinking about going to the opposite extreme, where individuals published their ratings universally, and any service that wanted to use them could do so. This would certainly help with the problems mentioned above, since the pool of ratings and would exist in many locations, and a user would only seed to update their set to update the world of services using. Sounds great! And this was when as "social" products were landing on the seen and peer-to-peer advancements were continuing apace, so I sat back with my movie popcorn and waited for this problem to be solved.

It's late in 2016, and I as far as I can tell there is nothing close to what I was hoping for. If anything, the situation has gotten worse. All eyes are going to massive companies that view the data is a precious asset which they're loath to share. Sites that do provide API access to this data do so under lengthy Terms of Use. I'm tired of waiting, so I'm taking a stab add building something myself. I have a lot less free time now so that's not helpful, but on the flip side technology
advances have me needing to roll a lot let stuff on my own.

# The Vision
Here are samples of what success looks like:

- When I rate or review articles (movies, books, etc.) on my desktop or phone, I only ever have to do so once.
- When I join a service that could use this data, I enter my public key and it's done.
- Companies can come and go, but my ratings are preserved across the thousands of sites that have replicated them.
- When I'm disconnected from the Internet, I can still access and mine and others' ratings.
- Predictions are better than ever.
- An individual has a wealth of data and comes up with novel recommendations spanning media types. They're able to provided this service to anyone interested, with no need to acquire a user base.
- My reputation is protected; others cannot publish as me.
- The system remains viable. Spam and other attacks are either prevented or can be effectively ignored.
- The system remains essentially a pool of data. It doesn't morph into a community, platform, messaging system, billboard, etc.
- The data lives on forever. Ratings today could form a recommendation for someone 20 years from now.


I'll be satisfied with even a small level of participation.

# Open Web
There are lots of open web and decentralization efforts. Many are massive efforts with very big goals. But I don't see how I would use them to quickly implement my very limited goals. Perhaps they can form the data sharing backbone at some point. In the mean time, I'm proposing a distribution method that is simple but sufficient.

# Scope
What data will be stored?

Ratings, reviews, and links to supporting information. Data about the article will be minimal and it is expected that the clients or sights will fetch supporting information as necessary.

What areas will it cover?

Published works. For starters, this **excludes** goods as services. But even still, "published works" is a huge domain. Certain types are have more potential than others. If there are too many items (e.g. songs, individual television episodes, wedpages), many users will not want to track, rate and receive recommendations at that level.

- movies
- television series
- podcasts

- books
- online video channels
- websites
- video games

I'll admit that this list is influence by design concerns. With an underlying goal of sharing rating information ~everywhere, I'm concerned about the practicality of trackings tens of thousands of items per user. For now, the focus is on the top three.



# References
- http://crosscloud.org
- https://github.com/solid/solid
- https://sandstorm.io
- https://techcrunch.com/2016/10/09/a-decentralized-web-would-give-power-back-to-the-people-online/
- http://www.streamingobserver.com/netflix-now-31-movies-imdbs-top-250-list/
