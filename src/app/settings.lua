local ttt = require("ttt")
local sys = require("ttt.system")
local storage = require("ttt.storage")
local U = require("core.util")
local S = require("core.state")
local UI = require("components")

local M = {}

M.PAGE_SIZES = {
  { label = "25 rows per page", value = "25" },
  { label = "50 rows per page", value = "50" },
  { label = "100 rows per page", value = "100" },
  { label = "250 rows per page", value = "250" },
}

M.TIMEOUTS = {
  { label = "10 seconds", value = "10" },
  { label = "30 seconds", value = "30" },
  { label = "1 minute", value = "60" },
  { label = "5 minutes", value = "300" },
  { label = "15 minutes", value = "900" },
  { label = "1 hour", value = "3600" },
  { label = "No timeout", value = "0" },
}

M.MAX_ROWS = {
  { label = "Keep 1,000 rows", value = "1000" },
  { label = "Keep 10,000 rows", value = "10000" },
  { label = "Keep 50,000 rows", value = "50000" },
  { label = "Keep 100,000 rows", value = "100000" },
}

M.on_change = nil

local function changed()
  storage.set("settings", S.settings)
  if M.on_change then
    M.on_change()
  end
end

local function set_path(path)
  S.psql_path = path
  S.settings.psql_path = path
  changed()
end

local function approved(path, granted)
  if granted then
    set_path(path)
    ttt.notify("Postgres: using " .. path)
  else
    ttt.notify("Postgres: " .. path .. " was not approved, still using " .. S.psql_path, "warn")
  end
end

local function file_name(path)
  return path:match("([^/\\]+)$") or ""
end

local function check_path(path)
  if path == "psql" then
    return nil
  end
  if not (path:sub(1, 1) == "/" or path:match("^%a:[/\\]")) then
    return "Use psql or an absolute path to psql"
  end
  local name = file_name(path)
  if name ~= "psql" and name ~= "psql.exe" then
    return "The plugin can only run a file named psql"
  end
end

-- ttt asks the user to approve an absolute path once; the approval dialog
-- needs the settings dialog closed first.
local function request(path)
  if not sys.request_exec then
    return ttt.notify("Postgres: the plugin needs the system.exec permission for psql", "error")
  end
  local ok, err = sys.request_exec(path, U.bind(approved, path))
  if not ok then
    ttt.notify("Postgres: can't use " .. path .. ": " .. tostring(err), "error")
  end
end

local function save(v, done)
  local path = U.trim(v.psql_path)
  if path == "" then
    path = "psql"
  end
  local err = check_path(path)
  if err then
    return done(err)
  end
  S.page_size = tonumber(v.page_size) or S.page_size
  S.query_timeout = tonumber(v.query_timeout) or S.query_timeout
  S.max_rows = tonumber(v.max_rows) or S.max_rows
  S.settings.page_size = S.page_size
  S.settings.query_timeout = S.query_timeout
  S.settings.max_rows = S.max_rows
  if path == "psql" then
    S.psql_path = path
    S.settings.psql_path = path
    changed()
    return done()
  end
  changed()
  done()
  request(path)
end

function M.dialog()
  UI.dialog({
    title = "PostgreSQL Settings",
    width = 64,
    hint = "ttt asks you once to approve a psql path.",
    fields = {
      {
        key = "psql_path",
        label = "psql binary (psql on PATH or an absolute path)",
        value = S.psql_path,
        required = true,
        placeholder = "psql",
      },
      {
        key = "page_size",
        label = "Page size",
        kind = "enum",
        options = M.PAGE_SIZES,
        value = tostring(S.page_size),
      },
      {
        key = "query_timeout",
        label = "Query timeout",
        kind = "enum",
        options = M.TIMEOUTS,
        value = tostring(S.query_timeout),
      },
      {
        key = "max_rows",
        label = "Query results",
        kind = "enum",
        options = M.MAX_ROWS,
        value = tostring(S.max_rows),
      },
    },
    on_submit = save,
  })
end

return M
