# PostgreSQL for ttt

Browse a [PostgreSQL](https://www.postgresql.org) database inside the [ttt](https://github.com/eugenioenko/ttt) terminal editor: switch schemas, page through tables and views, read their structure, and run SQL. The plugin talks to the server through `psql`, so it reaches any server `psql` can reach.

## Requirements

- **ttt newer than 1.9.0.** The plugin cancels, times out and streams `psql` through plugin APIs that landed after the 1.9.0 release (`sys.exec_async` handles and streaming, `sys.request_exec`). Until the next release, build ttt from `main`.
- **`psql`**, the PostgreSQL command line client. Any recent version works.
  - Debian and Ubuntu: `sudo apt install postgresql-client`.
  - macOS: `brew install libpq`. Homebrew installs libpq "keg-only", so `psql` is not on your `PATH`. Either run `brew link --force libpq`, or set the psql path in `Postgres: Settings…` to `/opt/homebrew/opt/libpq/bin/psql` (Apple Silicon) or `/usr/local/opt/libpq/bin/psql` (Intel).

ttt looks `psql` up on the `PATH` of the environment it was started from.

## Install

In ttt, open the command palette (Ctrl+P), run **Plugins: Install from URL** and enter:

```
https://github.com/eugenioenko/ttt-postgres
```

Once the plugin is listed in ttt's community registry, you can also install it from the **Plugins** sidebar tab by searching for "postgres".

To install by hand, clone it into ttt's plugins folder and restart ttt:

```sh
git clone https://github.com/eugenioenko/ttt-postgres.git ~/.config/ttt/plugins/postgres
```

### Permissions

ttt asks you to approve the plugin's permissions when it first loads:

- `system.exec` for `psql`: the plugin runs `psql` for every query. It may run no other program.
- `storage`: remembers saved connections, the current schema and the settings.
- `panel.sidebar`, `panel.editor` and `commands`: the Postgres sidebar panel, the table and query tabs, and the palette commands.

If you point the plugin at a `psql` outside your `PATH` (see [Settings](#settings)), ttt asks once more, showing the full path, when you save it. Allowing it approves that one file, and ttt remembers it across restarts. Other files called `psql` stay blocked.

## Connect

Open the **Postgres** sidebar panel (from the sidebar's » menu) and pick **Set up connection…**, or run `Postgres: New Connection…`. Fill in the host, port, database, user and password, or paste a connection URI such as `postgresql://user@host:5432/db?sslmode=require`, which replaces the fields. The name defaults to `database@host`. The plugin connects before it saves, so a typo shows up as psql's error in the dialog.

The password:

- Is **not saved** unless you tick **Save password**. Without it, ttt keeps it in memory until it exits and asks for it again next time.
- With **Save password**, it is stored in **plain text** in ttt's plugin storage (`~/.config/ttt/state/plugins/postgres.json`). The dialog warns about this while the box is ticked. Only save it for local, non-sensitive credentials.
- Can be left empty to let libpq find it: the `PGPASSWORD` variable of the environment ttt was started from, or `~/.pgpass`. A saved connection with an empty password connects without asking.

A password in a URI is taken out of the URI and treated the same way. psql gets the password through its own environment, never on its command line, and reads the SQL from standard input, so neither shows in the process list.

`Postgres: Connections…`, the panel's menu, or a click on the connection at the bottom of the panel lists the saved connections, with **Connect**, **Edit**, **Delete** and **New…**. When ttt starts, the plugin reconnects to the one you used last, unless it has to ask for its password.

## Use

The sidebar shows a schema switcher, a filter, and the tables and views of the schema with their estimated row counts. Activate one to open it in its own tab:

- **Data**: the rows, a page at a time, ordered by the primary key when there is one. Left and Right (or Shift+wheel) scroll wide tables sideways.
- **Structure**: columns, indexes, foreign keys in both directions, constraints, size, and a view's definition.
- **Query** opens a query tab on that table.

In a **query tab**, type SQL and press **F5** or **Run**. While it runs, the status line counts the rows received and a **Cancel** button stops it. Cancelling, or closing the tab, stops psql and asks the server to cancel the statement too. Running again while a query runs cancels the first run. The tab shows the result of the last statement that returns rows, with the row count, command tags such as `UPDATE 3`, and the server time. Errors show psql's message with the caret under the failing position.

Enter or a double click on a row shows every column of that row in full. Escape closes it.

### Commands

| Command | What it does |
|---------|--------------|
| `Postgres: Connections…` | Pick a saved connection to connect to, edit or delete |
| `Postgres: New Connection…` | Add a connection and connect to it |
| `Postgres: New Query` | Open a query tab |
| `Postgres: Run Query` | Run the query tab you used last |
| `Postgres: Refresh` | Reload the schema's tables and the open tabs |
| `Postgres: Reconnect` | Connect again to the current connection |
| `Postgres: Settings…` | Change the settings below |

## Settings

`Postgres: Settings…`:

| Setting | Default | What it does |
|---------|---------|--------------|
| psql binary | `psql` | `psql` from your `PATH`, or the absolute path of a file named `psql`, such as `/usr/lib/postgresql/16/bin/psql`. A path asks for your approval once (see [Permissions](#permissions)). |
| Page size | 50 rows | Rows per page in Data tabs and query results. |
| Query timeout | 5 minutes | How long a query tab or a Data page may run before psql is stopped and the statement cancelled. "No timeout" turns it off. The plugin's own catalog queries always stop after 30 seconds. |
| Query results | Keep 10,000 rows | Rows a query tab keeps from a result. The rest are counted, and the tab says "first 10,000 of N rows shown". |

## Limitations

- A query tab stops reading after 64 MiB of output from psql, even below the row limit, and shows the rows it has with a note. psql is stopped at that point, so later statements in the same run do not run.
- Quitting ttt or reloading the plugin while a query runs stops psql, but the statement keeps running on the server until it ends.
- The Data tab's row count is an exact `count(*)`, which can be slow on very large tables.
- Values that contain the ASCII control characters 0x1D to 0x1F cannot be told apart from psql's separators.

## Development

ttt loads a plugin from a single Lua file, so the source lives in `src/` as modules and `scripts/build.py` bundles them into `init.lua`. Edit `src/`, never `init.lua`, and rebuild:

```sh
scripts/build.py           # writes init.lua
scripts/build.py --check   # fails when init.lua is out of date
stylua --check src tests
scripts/test.py            # unit tests
```

A module's name is its path: `src/features/table/store.lua` is `require("features.table.store")`, and a folder's `init.lua` is the folder itself. The bundle runs `src/main.lua`.

```
src/main.lua            registration: sidebar, commands
src/core/               state, psql invocation, the output parser, catalog SQL, saved connections
src/components/         forms, dialogs, layout helpers, the result grid
src/app/                router (one editor tab per page), sidebar, connections, settings
src/features/table/     table tab: Data and Structure
src/features/query/     query tab
tests/unit/             unit tests and their runner
```

**Tests.** `scripts/test.py` bundles `src/` with `tests/unit/` and runs the tests headless through `ttt --plugin`, which provides the Lua runtime, so no Lua interpreter is needed. It uses `ttt` from `PATH`, or `TTT_BIN`. With `PGTEST_URI` (and `PGTEST_PASSWORD`) set, it also runs a smoke test in which the real plugin connects to that database and runs a query. CI runs the bundle check, stylua and the unit tests.

**How psql's output is read.** Every call runs `psql -X -q -w -v ON_ERROR_STOP=1 -A -F <US> -R <RS> -P footer=on -P null=<GS>` with the script on standard input. `-X` skips `~/.psqlrc` and `-w` never prompts for a password. Fields are separated by the ASCII unit separator (0x1F) and rows by the record separator (0x1E), so commas, quotes, tabs and line breaks in values need no unquoting, and NULL prints as the group separator (0x1D), distinct from an empty string. The footer stays on: a result set ends with `<RS>(N rows)`, which tells it apart from a command tag and lets several statements split cleanly. Query tabs also turn on `\timing` and set `FETCH_COUNT`, so psql streams large results instead of holding them in memory. Each script starts by printing the backend's pid and start time, which lets a cancel or a timeout cancel the statement on the server. `src/core/parse.lua` reads the output chunk by chunk as it streams in.
