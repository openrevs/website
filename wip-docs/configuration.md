# Configuration

Every CLI flag can also be set in a config file. Precedence, lowest to
highest:

1. Built-in defaults
2. `~/.dmrs/config.yaml`
3. `./dmrs.yaml` (current directory)
4. A file given with `--config FILE`
5. Flags on the command line

Command-line flags always win, so any instance can be fully redirected
ad hoc — useful for running several servers or TUIs at once when testing
sync:

```sh
dmrs server --data /tmp/s1 --listen :9001 &
dmrs server --data /tmp/s2 --listen :9002 &
dmrs tui --data /tmp/t1 --server http://localhost:9001
```

## File format

YAML (JSON also parses). Keys are grouped in a section named for the
command they configure and match the flag names; underscores may be used
in place of hyphens (`cut-interval` or `cut_interval`).

```yaml
server:
  data: /var/dmrs            # --data
  listen: ":1323"            # --listen
  cut-interval: 30m          # --cut-interval
  snapshot-every: 100        # --snapshot-every
  snapshot-chunk-size: 268435456  # --snapshot-chunk-size

client:
  data: /var/dmrs
  listen: ":1324"
  demo: false

clientserver:
  data: /var/dmrs
  server-listen: ":1323"
  client-listen: ":1324"
  cut-interval: 30m

tui:
  data: ~/.dmrs              # data directory / state location
  server: https://ratings.example.com
```

Sections are independent: a key under `server:` never affects `tui`.

## Note on the TUI

The `tui.data` key sets where the TUI keeps its state. The workspace
also maintains its own `config.json` *inside* that data directory
(currently just the server URL); that file is app-managed state, not
user configuration — `--server` (or `tui.server`) persists into it on
first use.
