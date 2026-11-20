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
`~/.revs`. The `tui` and `ui` data directories default to
`$REVS_HOME`, the `server` data directory defaults to
`$REVS_HOME/server`, and the user config file is read from
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
  part-size: 268435456       # --part-size: target size of each snapshot
                             # and patch archive part
  compact-every: [24, 168]   # --compact-every: epoch intervals at which
                             # patches are compacted into aligned ranges
  pull:                      # --pull URL (repeatable): upstream servers to
    - https://revs.example.com  # pull documents from (see Publishing)
  pull-interval: 15m         # --pull-interval: how often to pull them
  log-requests: false        # --log-requests: see "Request logging" below
  admin-listen: "127.0.0.1:1324"  # --admin-listen: serve the admin UI here;
                             # off by default (see "Server admin UI" below)

tui:
  data: ~/.revs              # the same collection as `ui`

ui:
  data: ~/.revs              # holds revs.db
  listen: "127.0.0.1:1325"
  no-browser: false
  log-requests: false
```

Sections are independent: a key under `server:` never affects `tui`.

## Request logging

`server` and `ui` accept `--log-requests`
(`log-requests: true` in the config file). It is off by default. When
it is on, every HTTP request the command serves gets one log line on
stderr, written once the response is finished:

```
INFO request method=GET path=/v1/ status=200 bytes=117 duration=195µs remote=127.0.0.1:63814 user_agent=curl/8.7.1
```

| Field        | Meaning                                       |
|--------------|-----------------------------------------------|
| `method`     | HTTP method                                   |
| `path`       | Request path, including any query string      |
| `status`     | Response status code                          |
| `bytes`      | Response body size in bytes                   |
| `duration`   | Time spent serving the request                |
| `remote`     | Client address as the server sees it          |
| `user_agent` | The `User-Agent` header                       |

Request and response bodies are never logged. Requests revs makes
itself, such as pulls from upstream servers, are not logged.

## Server admin UI

`revs server --admin-listen ADDR` serves a web UI for the server's
operator on a second address, separate from the public one so it can be
kept private (bind it to `127.0.0.1`, or a private network, and reach it
through a tunnel or an authenticating proxy). It is off unless
`admin-listen` is set.

The UI has one password, read from the `REVS_ADMIN_PASSWORD`
environment variable; there is no flag or config key for it, so it
stays out of process listings and config files. The server refuses to
start with `--admin-listen` but no password. Logging in gives a session
cookie good for 12 hours, or until the server restarts or you log out.

Failed logins are rate limited across all clients together, not per
address (behind a proxy every client has the same address): five may
fail at once, then one more every 12 seconds. While the limit is
reached, every login, right password or not, is refused with `429` and
a `Retry-After` header, so the limit also bounds guessing. Failed logins
are logged with the client's address.

For now the UI shows the server's state: its ID and uptime; how many
users it holds a document for, split into those uploaded directly and
those pulled from upstreams; how many document revisions it has
accepted and the total size of the latest ones; each channel's latest
epoch, member count and cut time; and each upstream's last pull, its
result, and the documents accepted from it since startup. With
JavaScript, the page keeps itself current over a Datastar stream,
checking every few seconds; without it, reload the page.

## Data directories

`tui` and `ui` are two front ends to the same collection, kept in
`~/.revs` (see [UI]({{ site.baseurl }}/specs/ui/)); they can run at the same time. The server's
data directory defaults to `~/.revs/server`: its `revs.db` would
otherwise collide with the UI's, and the directory also holds the server's identity (`server.key`), which signs
its manifests, and the published tree (`public/`); uploaded documents
are kept in `revs.db`. Any data directory is created on first run; back
up the server one to keep its identity.
