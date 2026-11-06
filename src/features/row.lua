local text = require("ttt.text")
local U = require("core.util")
local S = require("core.state")
local Psql = require("core.psql")
local Router = require("app.router")

local M = {}
local ids = setmetatable({}, { __mode = "k" })
local count = 0

local function value_lines(value, width)
  local out = {}
  for _, line in ipairs(U.split((value:gsub("\r\n", "\n")), "\n")) do
    local parts = text.wrap(line, width)
    if #parts == 0 then
      parts = { "" }
    end
    for _, part in ipairs(parts) do
      out[#out + 1] = part
    end
  end
  return out
end

local function row_values(entries, width, p)
  local key_width = 0
  for _, entry in ipairs(entries) do
    key_width = math.max(key_width, text.width(entry.key))
  end
  local content_width = math.max(width - 2, 1)
  local key_col = math.min(key_width + 2, math.floor(content_width / 2))
  local value_width = math.max(content_width - key_col - 2, 1)
  local wrapped = { muted_keys = true, padding_left = 1, padding_right = 1 }
  for _, entry in ipairs(entries) do
    for n, line in ipairs(value_lines(entry.value, value_width)) do
      wrapped[#wrapped + 1] = { key = n == 1 and entry.key or "", value = line }
    end
  end
  p:keyvalue(wrapped)
end

local function render(entries, p)
  S.active_query = nil
  p:scrollview({ render = U.bind(row_values, entries, p:size() - 1) })
end

local function page(title, columns, row)
  local entries = {}
  for c, name in ipairs(columns) do
    local value = row[c]
    entries[c] = { key = name, value = Psql.is_null(value) and "NULL" or value or "" }
  end
  return { title = title, render = U.bind(render, entries) }
end

function M.show(grid, title, i)
  local row = grid.rows[i]
  if not row then
    return
  end
  if not ids[row] then
    count = count + 1
    ids[row] = "row:" .. count
  end
  local heading = title .. " · row " .. tostring(grid.offset + i)
  return Router.show(ids[row], U.bind(page, heading, grid.columns, row), true)
end

return M
