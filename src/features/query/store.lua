local U = require("core.util")
local S = require("core.state")
local Psql = require("core.psql")
local SQL = require("core.sql")
local UI = require("components")

local M = {}

M.count = 0

function M.new(sql)
  M.count = M.count + 1
  return {
    id = M.count,
    title = "Query " .. M.count,
    sql = sql or "",
    running = false,
    ran = false,
    err = nil,
    notices = nil,
    summary = "",
    result = nil,
    gen = 0,
    grid = UI.grid.new(),
  }
end

local function summarize(q, statements)
  local ms, tags, result, count = 0, {}, nil, 0
  for _, st in ipairs(statements) do
    count = count + 1
    ms = ms + (st.ms or 0)
    if st.result then
      result = st.result
    end
    if st.tag then
      tags[#tags + 1] = st.tag
    end
  end
  local parts = {}
  if count > 1 then
    parts[#parts + 1] = U.plural(count, "statement")
  end
  if result then
    parts[#parts + 1] = U.plural(#result.rows, "row")
  end
  for _, tag in ipairs(tags) do
    parts[#parts + 1] = tag
  end
  parts[#parts + 1] = string.format("%.1f ms", ms)
  return table.concat(parts, " · "), result
end

local function finished(q, gen, out)
  if gen ~= q.gen then
    return
  end
  q.running = false
  q.ran = true
  q.err = out.err
  q.notices = nil
  if not out.err and U.trim(out.stderr) ~= "" then
    q.notices = U.trim(out.stderr)
  end
  local summary, result = summarize(q, out.statements or {})
  q.summary = summary
  q.result = result
  UI.grid.set_result(q.grid, result)
  S.redraw()
end

function M.run(q)
  if q.running then
    return
  end
  if U.trim(q.sql) == "" then
    q.err = "Type a query first."
    S.redraw()
    return
  end
  q.gen = q.gen + 1
  q.running = true
  q.err = nil
  S.redraw()
  Psql.run(SQL.query(q.sql), U.bind(finished, q, q.gen))
end

return M
