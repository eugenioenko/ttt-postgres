local U = require("core.util")

-- Reads psql's output (see core.psql) as it streams in. Chunks may split it
-- anywhere, so whatever follows the last complete record or line is carried
-- over to the next chunk. Each result set keeps its first max_rows rows and
-- counts the rest.
local M = {}

M.US = "\31"
M.RS = "\30"

local MARKER = "^ttt%-postgres backend (%d+) ([%d%.]+)$"
local FOOTER = "^%((%d+) rows?%)\n"
-- Longer than any "(N rows)\n" footer.
local SHORT = 32

function M.new(max_rows)
  return {
    max_rows = max_rows or math.huge,
    statements = {},
    cur = nil,
    set = nil,
    carry = {},
    carry_len = 0,
    received = 0,
    backend = nil,
  }
end

local function current(p)
  if not p.cur then
    p.cur = {}
    p.statements[#p.statements + 1] = p.cur
  end
  return p.cur
end

local function timing(line)
  local ms = line:match("^[^:]+: ([%d%.,]+) ms")
  if ms then
    return tonumber((ms:gsub(",", ".")))
  end
end

local function on_line(p, line)
  if not p.backend then
    local pid, started = line:match(MARKER)
    if pid then
      p.backend = { pid = tonumber(pid), started = started }
      return
    end
  end
  local ms = timing(line)
  if ms then
    current(p).ms = ms
    p.cur = nil
  elseif line ~= "" then
    current(p).tag = line
  end
end

local function on_header(p, header)
  local st = current(p)
  if st.result then
    p.cur = nil
    st = current(p)
  end
  st.result = { columns = U.split(header, M.US), rows = {}, total = 0, complete = false }
  p.set = st.result
end

local function on_row(p, s, i, j)
  local set = p.set
  set.total = set.total + 1
  p.received = p.received + 1
  if set.total <= p.max_rows then
    set.rows[set.total] = U.split(s:sub(i, j), M.US)
  end
end

-- The footer is told apart from a row that happens to look like one by its
-- count, which matches the rows read so far.
local function footer_end(p, s, pos)
  if s:byte(pos) ~= 40 then
    return nil
  end
  local _, fe, n = s:sub(pos, pos + SHORT):find(FOOTER)
  if fe and tonumber(n) == p.set.total then
    return pos + fe - 1
  end
end

local function consume(p, s)
  local pos, n = 1, #s
  while pos <= n do
    if p.set then
      local fe = footer_end(p, s, pos)
      if fe then
        p.set.complete = true
        p.set = nil
        pos = fe + 1
      else
        local rs = s:find(M.RS, pos, true)
        if not rs then
          break
        end
        on_row(p, s, pos, rs - 1)
        pos = rs + 1
      end
    else
      local at = s:find("[\30\n]", pos)
      if not at then
        break
      end
      if s:byte(at) == 10 then
        on_line(p, s:sub(pos, at - 1))
      else
        on_header(p, s:sub(pos, at - 1))
      end
      pos = at + 1
    end
  end
  return s:sub(pos)
end

local function completes(p, chunk)
  if p.set then
    return chunk:find(M.RS, 1, true) or (p.carry_len < SHORT and chunk:find("\n", 1, true))
  end
  return chunk:find("[\30\n]")
end

function M.feed(p, chunk)
  if chunk == "" then
    return
  end
  if p.carry_len > 0 then
    local done = completes(p, chunk)
    p.carry[#p.carry + 1] = chunk
    p.carry_len = p.carry_len + #chunk
    if not done then
      return
    end
    chunk = table.concat(p.carry)
  end
  local rest = consume(p, chunk)
  p.carry = { rest }
  p.carry_len = #rest
end

-- An unfinished result set keeps complete = false; its last, partial record
-- is dropped.
function M.finish(p)
  local rest = table.concat(p.carry)
  p.carry, p.carry_len = {}, 0
  if p.set then
    if footer_end(p, rest .. "\n", 1) then
      p.set.complete = true
    end
    p.set = nil
  elseif rest ~= "" then
    on_line(p, rest)
  end
  return p.statements
end

return M
