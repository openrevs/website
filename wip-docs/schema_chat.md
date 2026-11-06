https://claude.ai/chat/77c4cc50-984a-4a08-9c8d-ac55ee37bb52

Here is some sample yaml. Make a rough json schema definition from it:

user:
  id: abc123
  minrating: 0
  maxrating: 5
titles:
  - name: Pulp Fiction
    year: 1994
    TMDB_ID: 680
    reviews:
      - rating: 4
        date: 2023-03-24
        comment: |
          This is a multi-line review.
          It's pretty cool.
      - rating: 5
        date: 1999-03-24
        comment: Great movie!!!
  - name: Rocky Balboa
    year: 2006
    refs:
      imdb_id: tt0479143
    reviews:
      - rating: 3
        date: 2023-03-27
        comment: >
          Mildly enjoyable, mainly because of the nostalgia factor (which the film leans into
          explicity). The production was fine and like the Marie character, but the main issue
          was that the plot lacked any kinda of nemesis. The inevitable opponent (Mason Dixon)
          was perfectly likable with his own struggles, so that element of a Rocky film was
          lacking. The minor subplots (e.g. Rocky's relationship with his son, or Mason's with
          his promoters, were hastily done at best). So fairly week, but Rocky is always an
          enjoyable character and carried the film.


{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.org/schemas/reviews.json",
  "type": "object",
  "properties": {
    "user": {
      "type": "object",
      "properties": {
        "id": { "type": "string" },
        "minrating": { "type": "number" },
        "maxrating": { "type": "number" }
      },
      "required": ["id"],
      "additionalProperties": false
    },
    "titles": {
      "type": "array",
      "items": { "$ref": "#/$defs/title" }
    }
  },
  "required": ["titles"],
  "additionalProperties": false,

  "$defs": {
    "title": {
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "year": { "type": "integer", "minimum": 1870 },
        "TMDB_ID": { "type": "integer" },
        "refs": { "$ref": "#/$defs/refs" },
        "reviews": {
          "type": "array",
          "items": { "$ref": "#/$defs/review" }
        }
      },
      "required": ["name"],
      "additionalProperties": false
    },

    "refs": {
      "type": "object",
      "properties": {
        "imdb_id": { "type": "string", "pattern": "^tt[0-9]{7,8}$" },
        "tmdb_id": { "type": "integer" }
      },
      "additionalProperties": false
    },

    "review": {
      "type": "object",
      "properties": {
        "rating": { "type": "number", "minimum": 0 },
        "date": { "type": "string", "format": "date" },
        "comment": { "type": "string" }
      },
      "required": ["rating"],
      "additionalProperties": false
    }
  }
}

Two things the sample surfaces that are worth deciding before this hardens:

External IDs are in two places. Pulp Fiction uses a top-level TMDB_ID, Rocky uses refs.imdb_id. I kept both so the schema validates your sample as-is, but you probably want everything under refs with lowercase keys, and possibly minProperties: 1 on it if a title must be resolvable to something.

minrating/maxrating live on user, but ratings live on reviews. JSON Schema can’t express “rating must fall within the user’s declared scale” — that’s a cross-branch constraint. Options: fix the scale in the schema (0–5 or 0–10) and drop the user-declared bounds, or keep the declaration and validate the relationship in application code. Also unclear whether rating is integer-only; the sample has only whole numbers, but a 0–5 scale often wants halves, so I left it as number.



