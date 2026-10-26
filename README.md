# PostgreSQL for ttt

Browse a [PostgreSQL](https://www.postgresql.org) database inside the [ttt](https://github.com/eugenioenko/ttt) terminal editor: switch schemas, page through the rows of a table or view, read its structure, and run SQL.

The plugin talks to the server through `psql`, the PostgreSQL command line client, so it works with any server `psql` can reach and needs no driver of its own.

## Features

The **Postgres** sidebar panel has a schema switcher, a filter, and the tables and views of the current schema. Tables show their estimated row count (from the planner statistics, so it costs nothing), materialized views show `mat`. Activating a table or view opens it in its own editor tab, and opening it again focuses that tab.

- **Data**: the rows, a page at a time. Paging runs `LIMIT`/`OFFSET` on the server, ordered by the primary key when there is one, and the total comes from `count(*)`. Enter on a row shows every column in full, NULLs and line breaks included.
- **Structure**: kind, estimated rows, size and primary key; the columns with their type, nullability, default (identity and generated columns too) and PK/FK markers; indexes with their definition and size; foreign keys; the foreign keys of other tables that point here; unique, check and exclusion constraints. Views show their definition.
- **Query**: a SQL editor in its own tab. **Run** or F5 runs everything in it. The result of the last statement that returns rows shows in a table, with the row count, the command tags (`UPDATE 3`, `ROLLBACK`) and the server time. Errors show psql's message as it prints it, with the caret under the failing position, and notices show below the editor.

Commands in the palette:

| Command | What it does |
|---------|--------------|
| `Postgres: Connect…` | Set the connection |
| `Postgres: New Query` | Open a query tab |
| `Postgres: Run Query` | Run the query tab you used last |
| `Postgres: Refresh` | Reload the schema's tables and the open tabs |
| `Postgres: Reconnect` | Connect again with the saved settings |
| `Postgres: Settings…` | Set the psql binary and the page size |

The panel's menu has the same entries, and each table tab has a **Query** button that opens a query on that table.

## Requirements

`psql`, the PostgreSQL client, on your `PATH`. On Debian and Ubuntu it is in the `postgresql-client` package, on macOS in `libpq` or `postgresql` from Homebrew.

## Install

Clone the repository and link it into ttt's plugins folder, then restart ttt:

```sh
git clone https://github.com/eugenioenko/ttt-postgres.git
ln -s "$PWD/ttt-postgres" ~/.config/ttt/plugins/postgres
```

ttt asks you to approve the permissions on first start. The plugin uses `system.exec` for `psql`, `storage` (to remember the connection, the schema and the settings), `panel.sidebar`, `panel.editor` and `commands`.

## Connecting

Open the **Postgres** sidebar panel and pick **Set up connection…**, or run `Postgres: Connect…`. Fill in the host, port, database, user and password, or paste a connection URI (`postgresql://user:password@host:5432/db?sslmode=require`), which replaces the fields. The plugin connects before it saves, so a typo shows up as psql's error in the dialog.

Leave the password empty to let libpq find it the usual way: the `PGPASSWORD` variable of the environment ttt was started from, or `~/.pgpass`. That is the safer choice. A password typed in the dialog is saved in plain text in ttt's plugin storage (`~/.config/ttt/state/plugins/postgres.json`) and goes to psql inside its connection string argument, which other users of the machine can see in the process list while a query runs. ttt's process API has no way to set a child's environment, so the plugin cannot pass it through `PGPASSWORD` itself.

The SQL never goes on the command line: psql reads it from standard input.

### Another psql

`Postgres: Settings…` sets the psql binary. ttt only runs binaries the manifest lists under `system.exec`, matched exactly, so a full path such as `/usr/lib/postgresql/16/bin/psql` must also be added to `plugin.ttt.json` and the plugin approved again. A wrapper script on your `PATH` named `psql` works without that, for example one that runs psql in Docker:

```sh
#!/bin/sh
exec docker run --rm -i --network host -e PGPASSWORD postgres:16 psql "$@"
```

## How psql's output is read

Every call runs `psql -X -q -w -v ON_ERROR_STOP=1 -A -F <US> -R <RS> -P footer=on -P null=<GS> -d <connection>` with the script on standard input:

- `-X` skips `~/.psqlrc`, so its settings cannot change the output, and `-w` makes psql fail instead of prompting for a password on the terminal ttt is drawing on.
- `-A` with the ASCII unit separator (0x1F) between fields and the record separator (0x1E) between rows means values with commas, quotes, tabs, pipes or line breaks come through as they are, with nothing to unquote. CSV would also be lossless, but needs a quote-aware parser, and NULL and the empty string look the same in it.
- NULL prints as the group separator (0x1D), so it differs from an empty string and from the text `NULL`.
- The footer stays on: a result set always ends with a record separator followed by `(N rows)`, which tells it apart from a command tag such as `UPDATE 3`. That way several statements in one run split cleanly, and the plugin's own catalog queries ask for several result sets in one call.
- Query tabs turn on `\timing` to report the server time of each statement.

The one thing this cannot carry is a value that itself contains those control characters, which text columns almost never do.

## Development

ttt loads a plugin from a single Lua file, so the source lives in `src/` as modules and `scripts/build.py` bundles them into `init.lua`. Edit `src/`, never `init.lua`, and rebuild:

```sh
scripts/build.py           # writes init.lua
scripts/build.py --check   # fails when init.lua is out of date
```

A module's name is its path: `src/features/table/store.lua` is `require("features.table.store")`, and a folder's `init.lua` is the folder itself, so `src/features/table/init.lua` is `require("features.table")`. `ttt.*` modules resolve as usual. The bundle runs `src/main.lua`.

```
src/main.lua            registration: sidebar, commands
src/core/               state, psql invocation and parsing, catalog SQL, connection
src/components/         forms, dialogs, layout helpers, the result grid
src/app/                router (one editor tab per page), sidebar, connection, settings
src/features/table/     table tab: Data and Structure
src/features/query/     query tab
```

## Limitations

- A running query cannot be cancelled from ttt; set `statement_timeout` in the connection URI's `options` if you need a bound.
- A query tab keeps the whole result of its last statement in memory and pages it locally.
- The row count of the Data tab is an exact `count(*)`, which can be slow on very large tables.
