local sys = require("ttt.system")
local U = require("core.util")
local S = require("core.state")
local Saved = require("core.saved")
local Parse = require("core.parse")

-- psql runs unaligned with the ASCII unit and record separators between
-- fields and rows, and a control character for NULL, so values with commas,
-- quotes, tabs or newlines need no unquoting. The footer stays on: a result
-- set always ends in "<RS>(N rows)\n", which tells it apart from a command
-- tag such as "UPDATE 3".
local M = {}

M.US = Parse.US
M.RS = Parse.RS
M.NULL = "\29"

local function quote(v)
  local s = tostring(v):gsub("\\", "\\\\"):gsub("'", "\\'")
  return "'" .. s .. "'"
end

local function add(parts, key, value)
  value = U.trim(value)
  if value ~= "" then
    parts[#parts + 1] = key .. "=" .. quote(value)
  end
end

-- The password never goes into the connection string: psql gets it through
-- PGPASSWORD, which other users cannot read in the process list.
function M.target(conn)
  local uri, uri_password = Saved.split_uri(conn.uri)
  local password = (conn.password or "") ~= "" and conn.password or uri_password or ""
  if uri ~= "" then
    return uri, password
  end
  local parts = {}
  add(parts, "host", conn.host)
  add(parts, "port", conn.port)
  add(parts, "dbname", conn.database)
  add(parts, "user", conn.user)
  add(parts, "connect_timeout", "10")
  add(parts, "application_name", "ttt-postgres")
  return table.concat(parts, " "), password
end

function M.args(conninfo)
  return {
    "-X",
    "-q",
    "-w",
    "-v",
    "ON_ERROR_STOP=1",
    "-A",
    "-F",
    M.US,
    "-R",
    M.RS,
    "-P",
    "footer=on",
    "-P",
    "null=" .. M.NULL,
    "-d",
    conninfo,
  }
end

local function clean_error(text)
  local out = {}
  for _, line in ipairs(U.lines(text)) do
    line = line:gsub("^psql:[^:]*:%d+: ", "")
    line = line:gsub("^psql: error: ", "")
    out[#out + 1] = line
  end
  return table.concat(out, "\n")
end

function M.error_text(res)
  local stderr = U.trim(res.stderr)
  if res.exit_code == -1 then
    if stderr:find("not found", 1, true) or stderr:find("no such file", 1, true) then
      return "psql was not found ("
        .. S.psql_path
        .. "). Install the PostgreSQL client or set its path in Postgres: Settings…"
    end
    return stderr ~= "" and stderr or "psql could not be started"
  end
  if stderr == "" then
    return "psql exited with code " .. tostring(res.exit_code)
  end
  return clean_error(stderr)
end

M.OUTPUT_LIMIT = 64 * 1024 * 1024
M.OUTPUT_LIMIT_LABEL = "64 MiB"
M.CATALOG_TIMEOUT_MS = 30000

-- Killing psql leaves its statement running on the server, so a cancel or a
-- timeout also cancels the backend. Its start time guards against a reused
-- pid.
local PRELUDE = "select pg_backend_pid() as ttt_pid, coalesce((select extract(epoch from backend_start)::text"
  .. " from pg_stat_activity where pid = pg_backend_pid()), '0') as ttt_started \\gset\n"
  .. "\\echo ttt-postgres backend :ttt_pid :ttt_started\n"

local CANCEL = "select pg_cancel_backend(pid) from pg_stat_activity"
  .. " where pid = %d and extract(epoch from backend_start)::text = %s;\n"

local function ignore() end

local function cancel_backend(run)
  local b = run.parser.backend
  if not b then
    return
  end
  local opts = { stdin = string.format(CANCEL, b.pid, U.literal(b.started)), timeout_ms = 10000 }
  if run.password ~= "" then
    opts.env = { PGPASSWORD = run.password }
  end
  sys.exec_async(run.path, M.args(run.conninfo), opts, ignore)
end

local function stdout(run, chunk)
  Parse.feed(run.parser, chunk)
  if run.on_progress then
    run.on_progress(run.parser.received)
  end
end

local function finished(run, cb, res)
  local out = {
    stderr = res.stderr or "",
    code = res.exit_code,
    statements = Parse.finish(run.parser),
    elapsed = os.clock() - run.started,
  }
  if res.cancelled then
    out.stopped = "cancelled"
  elseif res.timed_out then
    out.stopped = "timed_out"
  elseif res.truncated then
    out.stopped = "truncated"
  elseif res.exit_code ~= 0 then
    out.err = M.error_text(res)
  end
  if out.stopped then
    cancel_backend(run)
  end
  cb(out)
end

local function exec_error(path, err)
  local msg = tostring(err)
  if not msg:find("permission denied", 1, true) then
    return msg
  end
  if path ~= "psql" then
    return path .. " is not approved. Save it in Postgres: Settings… to approve it."
  end
  return msg .. ". Approve the plugin's system.exec permission for psql."
end

-- Runs a script on psql's standard input, so neither the SQL nor its length
-- reaches the command line. opts: timeout_ms, max_rows (kept per result set)
-- and on_progress(rows_received). cb(out) gets { statements, stderr, err,
-- stopped = "cancelled"|"timed_out"|"truncated", elapsed }. Returns a handle
-- for M.cancel, or nil when psql could not start.
function M.run(script, opts, cb)
  if not sys.exec_async then
    cb({ err = "The plugin needs the system.exec permission for psql.", statements = {} })
    return nil
  end
  local conninfo, password = M.target(S.conn)
  local run = {
    parser = Parse.new(opts.max_rows),
    path = S.psql_path,
    conninfo = conninfo,
    password = password,
    on_progress = opts.on_progress,
    started = os.clock(),
  }
  local exec_opts = {
    stdin = PRELUDE .. script,
    timeout_ms = opts.timeout_ms,
    max_output_bytes = M.OUTPUT_LIMIT,
    on_stdout = U.bind(stdout, run),
  }
  if password ~= "" then
    exec_opts.env = { PGPASSWORD = password }
  end
  local handle, err = sys.exec_async(run.path, M.args(conninfo), exec_opts, U.bind(finished, run, cb))
  if not handle then
    cb({ err = exec_error(run.path, err), statements = {} })
    return nil
  end
  run.handle = handle
  return run
end

function M.cancel(run)
  if run and run.handle then
    run.handle:cancel()
  end
end

function M.stopped_text(out, timeout_ms)
  if out.stopped == "timed_out" then
    return "No result after " .. U.duration(timeout_ms / 1000) .. ", so psql was stopped."
  elseif out.stopped == "truncated" then
    return "psql's output passed " .. M.OUTPUT_LIMIT_LABEL .. ", so it was stopped."
  end
  return "Cancelled."
end

local function results(cb, timeout_ms, out)
  if out.stopped then
    return cb(M.stopped_text(out, timeout_ms))
  end
  if out.err then
    return cb(out.err)
  end
  local list = {}
  for _, st in ipairs(out.statements) do
    if st.result then
      list[#list + 1] = st.result
    end
  end
  cb(nil, list)
end

-- For the plugin's own queries: cb(err, result_sets). opts.timeout_ms
-- replaces the catalog timeout; nil there means none.
function M.query(sql, cb, opts)
  local timeout = M.CATALOG_TIMEOUT_MS
  if opts then
    timeout = opts.timeout_ms
  end
  M.run(sql, { timeout_ms = timeout }, U.bind(results, cb, timeout))
end

function M.is_null(v)
  return v == M.NULL
end

return M
