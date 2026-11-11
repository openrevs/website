---
title: Rating Scales
parent: Specifications
published: false
permalink: /specs/ratings/
---

# Rating scales

A ratingset's user line declares the scale that every rating in the
document uses. Ratings are integers, and the scale is the inclusive
range `min_rating`..`max_rating`:

```json
{"id":"601b27ee…","min_rating":0,"max_rating":10,"revision":4}
{"type":"movie","name":"Pulp Fiction","year":1994,"reviews":[{"date":"2020-01-01","rating":9}]}
```

Here `9` on a 0–10 scale means 4½ of 5 stars.

## What revs publishes

revs stores and publishes ratings in **half stars**: `min_rating` 0
and `max_rating` 10, where 0 is no stars and 10 is five stars. The
user enters and sees star ratings in steps of ½ (`3.5`, shown as
`★★★½☆`); the integer in the document is twice that.

Earlier versions of revs published whole stars (`max_rating` 5).

## Reading other documents

Different authors and different clients may use different scales, so
a consumer must read each document's ratings against that document's
own `min_rating` and `max_rating`, never against a fixed scale. To
compare or display ratings from several documents, convert them
proportionally:

```
fraction = (rating - min_rating) / (max_rating - min_rating)
```

revs converts every rating it imports or pulls from a server this way,
to its own half-star scale, rounding to the nearest half star.

Edge cases, as revs handles them:

- **No review `rating`:** the review is unrated. Unrated is different
  from a rating of `min_rating`.
- **Rating outside the declared range:** the rating is ignored, and the
  review is kept as unrated.
- **No scale declared:** this covers an unsigned file without a user
  line, a user line without `max_rating`, or one where `max_rating` is
  not greater than `min_rating`. revs assumes the legacy whole-star
  scale, 0–5.

## Notes for client authors

- Declare the scale your ratings actually use, and keep it fixed for a
  user's documents where you can. Changing the scale changes every
  rating line, so the next revision rewrites the whole document.
- Prefer a scale whose steps match what users can enter. A 0–10 scale
  for half stars converts exactly; a scale that's too coarse loses
  precision for everyone reading the document.
