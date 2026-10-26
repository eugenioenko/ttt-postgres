local sys = require("ttt.system")
local U = require("core.util")
local S = require("core.state")

-- psql runs unaligned with the ASCII unit and record separators between
-- fields and rows, and a control character for NULL, so values with commas,
-- quotes, tabs or newlines need no unquoting. The footer stays on: a result
-- set always ends in "<RS>(N rows)\n", which tells it apart from a command
-- tag such as "UPDATE 3".
local M = {}

M.US = "\31"
M.RS = "\30"
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

-- Every value is quoted, so no argument holds "=!", which ttt refuses.
function M.conninfo(conn)
  local uri = U.trim(conn.uri)
  if uri ~= "" then
    return uri
  end
  local parts = {}
  add(parts, "host", conn.host)
  add(parts, "port", conn.port)
  add(parts, "dbname", conn.database)
  add(parts, "user", conn.user)
  if conn.password and conn.password ~= "" then
    parts[#parts + 1] = "password=" .. quote(conn.password)
  end
  add(parts, "connect_timeout", "10")
  add(parts, "application_name", "ttt-postgres")
  return table.concat(parts, " ")
end

function M.args(conn)
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
    M.conninfo(conn),
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

local function records(body)
  local rows = {}
  for i, record in ipairs(U.split(body, M.RS)) do
    rows[i] = U.split(record, M.US)
  end
  return rows
end

local function timing(line)
  local ms = line:match("^[^:]+: ([%d%.,]+) ms")
  if ms then
    return tonumber((ms:gsub(",", ".")))
  end
end

local function statement(list, cur)
  if not cur then
    cur = {}
    list[#list + 1] = cur
  end
  return cur
end

-- Splits psql's output into statements: { result = { columns, rows }, tag, ms }.
function M.parse(out)
  local list, cur = {}, nil
  local pos, n = 1, #out
  while pos <= n do
    local nl = out:find("\n", pos, true) or (n + 1)
    local line = out:sub(pos, nl - 1)
    local fs = line:find(M.RS, 1, true) and out:find(M.RS .. "%(%d+[^%)\n]*%)\n", pos)
    if fs then
      local rows = records(out:sub(pos, fs - 1))
      local columns = table.remove(rows, 1) or {}
      cur = statement(list, cur)
      if cur.result then
        cur = statement(list, nil)
      end
      cur.result = { columns = columns, rows = rows }
      local _, fe = out:find("%)\n", fs)
      pos = fe + 1
    else
      local ms = timing(line)
      if ms then
        statement(list, cur).ms = ms
        cur = nil
      elseif line ~= "" then
        cur = statement(list, cur)
        cur.tag = line
      end
      pos = nl + 1
    end
  end
  return list
end

local function finished(cb, res)
  local out = { stdout = res.stdout or "", stderr = res.stderr or "", code = res.exit_code }
  if res.exit_code ~= 0 then
    out.err = M.error_text(res)
  end
  out.statements = M.parse(out.stdout)
  cb(out)
end

-- Runs a script on psql's standard input, so neither the SQL nor its length
-- reaches the command line.
function M.run(script, cb)
  if not sys.exec_async then
    return cb({ err = "The plugin needs the system.exec permission for psql.", statements = {} })
  end
  local _, err = sys.exec_async(S.psql_path, M.args(S.conn), { stdin = script }, U.bind(finished, cb))
  if err then
    local msg = tostring(err)
    if msg:find("permission denied", 1, true) then
      msg = msg .. ". Add it to system.exec in plugin.ttt.json and approve the plugin again."
    end
    cb({ err = msg, statements = {} })
  end
end

local function results(cb, out)
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

-- For the plugin's own catalog queries: cb(err, result_sets).
function M.query(sql, cb)
  M.run(sql, U.bind(results, cb))
end

function M.is_null(v)
  return v == M.NULL
end

return M
