local U = require("core.util")
local S = require("core.state")
local Psql = require("core.psql")
local SQL = require("core.sql")
local UI = require("components")

local M = {}

M.count = 0

local REDRAW_EVERY = 0.1

function M.new(sql)
  M.count = M.count + 1
  return {
    id = M.count,
    title = "Query " .. M.count,
    sql = sql or "",
    running = false,
    run = nil,
    received = 0,
    drawn_at = 0,
    ran = false,
    err = nil,
    stopped = nil,
    notices = nil,
    summary = "",
    shown = nil,
    result = nil,
    gen = 0,
    grid = UI.grid.new(),
  }
end

local function rows_part(result, stopped)
  local kept, total = #result.rows, result.total
  if result.complete then
    if total > kept then
      return "first " .. U.thousands(kept) .. " of " .. U.plural(total, "row") .. " shown"
    end
    return U.plural(total, "row")
  end
  if total > kept or stopped == "truncated" then
    return "first " .. U.plural(kept, "row") .. " shown"
  end
  return U.plural(kept, "row") .. " received"
end

-- Why the grid holds fewer rows than the query returned, if it does.
local function shown_note(result, stopped)
  local kept = #result.rows
  if stopped == "truncated" then
    return "First "
      .. U.plural(kept, "row")
      .. " shown: psql's output passed "
      .. Psql.OUTPUT_LIMIT_LABEL
      .. ", so it was stopped."
  elseif stopped == "cancelled" or stopped == "timed_out" then
    return U.plural(kept, "row") .. " arrived before the query was stopped."
  elseif result.total > kept then
    return "First "
      .. U.thousands(kept)
      .. " of "
      .. U.plural(result.total, "row")
      .. " shown. The limit is in Postgres: Settings…"
  end
end

local function summarize(statements, stopped, elapsed)
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
    parts[#parts + 1] = rows_part(result, stopped)
  end
  for _, tag in ipairs(tags) do
    parts[#parts + 1] = tag
  end
  if stopped then
    parts[#parts + 1] = U.duration(elapsed)
  else
    parts[#parts + 1] = string.format("%.1f ms", ms)
  end
  return table.concat(parts, " · "), result
end

local function finished(q, gen, timeout, out)
  if gen ~= q.gen then
    return
  end
  q.run = nil
  q.running = false
  q.ran = true
  q.stopped = out.stopped
  q.err = out.err
  if out.stopped == "timed_out" then
    q.err = "The query ran longer than the "
      .. U.duration(timeout)
      .. " timeout, so psql was stopped. The timeout is in Postgres: Settings…"
  end
  q.notices = nil
  if not out.err and not out.stopped and U.trim(out.stderr) ~= "" then
    q.notices = U.trim(out.stderr)
  end
  local summary, result = summarize(out.statements or {}, out.stopped, out.elapsed or 0)
  q.summary = summary
  q.result = result
  q.shown = result and shown_note(result, out.stopped)
  UI.grid.set_result(q.grid, result)
  S.redraw()
end

local function progress(q, gen, received)
  if gen ~= q.gen then
    return
  end
  q.received = received
  local now = os.clock()
  if now - q.drawn_at >= REDRAW_EVERY then
    q.drawn_at = now
    S.redraw()
  end
end

-- Stops the running query; its callback reports it as cancelled.
function M.cancel(q)
  Psql.cancel(q.run)
end

-- Closing the tab drops the query without reporting it.
function M.abandon(q)
  q.gen = q.gen + 1
  Psql.cancel(q.run)
  q.run = nil
  q.running = false
end

-- Running again while a query runs cancels it first.
function M.run(q)
  if U.trim(q.sql) == "" then
    q.err = "Type a query first."
    S.redraw()
    return
  end
  M.abandon(q)
  q.running = true
  q.err = nil
  q.received = 0
  local opts = { timeout_ms = S.query_timeout_ms(), max_rows = S.max_rows, on_progress = U.bind(progress, q, q.gen) }
  q.run = Psql.run(SQL.query(q.sql), opts, U.bind(finished, q, q.gen, S.query_timeout))
  S.redraw()
end

return M
