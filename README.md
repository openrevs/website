# OpenRevs website

Live at https://openrevs.org. Published with GitHub Pages (deploy from `main`);
GitHub builds it with Jekyll on every push, so there's nothing to install.

Theme: [Just the Docs](https://just-the-docs.com), set in `_config.yml`.

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
