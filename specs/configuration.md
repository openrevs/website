---
title: Configuration
parent: Specifications
published: false
permalink: /specs/configuration/
---

# Configuration

Every CLI flag can also be set in a config file. Precedence, lowest to
highest:

1. Built-in defaults
2. `$REVS_HOME/config.yaml` (`~/.revs/config.yaml` if `REVS_HOME` is unset)
3. `./revs.yaml` (current directory)
4. A file given with `--config FILE`
5. Flags on the command line

Command-line flags always win, so any instance can be fully redirected
ad hoc — useful for running several servers or collections at once when
testing sync:

```sh
revs server --data /tmp/s1 --listen :9001 &
revs server --data /tmp/s2 --listen :9002 &
revs tui --data /tmp/t1     # then add the servers under "3 Servers"
```

## REVS_HOME

`REVS_HOME` sets the root directory revs works from. It defaults to
`~/.revs`. The `tui`, `ui` and `client` data directories default to
`$REVS_HOME`, the `server` and `clientserver` data directories default
to `$REVS_HOME/server`, and the user config file is read from
`$REVS_HOME/config.yaml`. A `--data` flag or config value still
overrides the default.

Because the identity key, collection, server list and config all live
under that root, a different `REVS_HOME` is a separate user. To test as
several people, give each terminal its own:

```sh
export REVS_HOME=~/revs-test/alice   # this shell is Alice
revs tui

REVS_HOME=~/revs-test/bob revs ui --listen 127.0.0.1:8081
```

Two `revs ui` instances still need different `--listen` addresses.

## File format

YAML (JSON also parses). Keys are grouped in a section named for the
command they configure and match the flag names; underscores may be used
in place of hyphens (`cut-interval` or `cut_interval`).

```yaml
server:
  data: /var/revs            # --data; default ~/.revs/server
  listen: ":1323"            # --listen
  cut-interval: 30m          # --cut-interval
  snapshot-every: 100        # --snapshot-every
  publish-on-upload: false   # --publish-on-upload: cut an epoch right after
                             # each accepted upload (for testing)
  snapshot-chunk-size: 268435456  # --snapshot-chunk-size

client:
  data: /var/revs            # default ~/.revs/server
  listen: ":1324"
  demo: false

clientserver:
  data: /var/revs
  server-listen: ":1323"
  client-listen: ":1324"
  cut-interval: 30m

tui:
  data: ~/.revs              # the same collection as `ui`

ui:
  data: ~/.revs              # holds revs.db and servers/
  listen: "127.0.0.1:1325"
  no-browser: false
```

Sections are independent: a key under `server:` never affects `tui`.

## Data directories

`tui` and `ui` are two front ends to the same collection, kept in
`~/.revs` (see [UI]({{ site.baseurl }}/specs/ui/)); they can run at the same time. The server commands
(`server`, `client`, `clientserver`) default to `~/.revs/server`: the
server's `revs.db` would otherwise collide with the UI's, and the
directory also holds the server's identity (`server.key`), its document
store (`docs/`), and the published tree (`public/`). Any data directory
is created on first run; back up the server one to keep its identity.
