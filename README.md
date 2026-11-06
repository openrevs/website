# OpenRevs website

Live at https://openrevs.org. Published with GitHub Pages (deploy from `main`);
GitHub builds it with Jekyll on every push, so there's nothing to install.

Theme: [Just the Docs](https://just-the-docs.com), set in `_config.yml`.

## Local preview

Only Docker is needed — no Ruby, gems, or version managers on the host.

```sh
docker compose up        # then open http://localhost:4000
```

Edits are picked up automatically and the browser reloads. Stop with ctrl-c
(or `docker compose down` if started with `-d`).

The first run builds the image (a few minutes); later runs start in seconds.
After changing the `Dockerfile`, rebuild with `docker compose up --build`.

The image installs the `github-pages` gem, which pins the same Jekyll and
plugin versions GitHub Pages uses, so the preview matches the live site. Output
goes to `_site/` (gitignored). The theme is fetched from GitHub on each build,
so a network connection is required.

## Adding pages

Create a `.md` file with front matter, then start the body with a `# Heading`:

```markdown
---
title: My Page
nav_order: 6            # position in the sidebar
permalink: /my-page/
---

# My Page
```

A new spec goes in `specs/` with `parent: Specifications`; it shows up under
Specifications in the sidebar and in the list on the Specifications page.

Docs for navigation, callouts, and more: https://just-the-docs.com/docs/navigation/
