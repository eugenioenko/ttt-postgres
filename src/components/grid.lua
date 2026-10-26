local ttt = require("ttt")
local text = require("ttt.text")
local U = require("core.util")
local S = require("core.state")
local Psql = require("core.psql")

-- A page of a result set as a table with a pager. The rows on show are
-- grid.rows; a client grid slices them from grid.all, a server grid asks
-- grid.on_page for the rows at the new offset.
local M = {}

local MAX_CELL = 200
local MAX_WIDTH = 60

function M.new(spec)
  local grid = {
    columns = {},
    rows = {},
    all = nil,
    offset = 0,
    total = 0,
    sel = 1,
    loading = false,
    loaded = false,
    err = nil,
  }
  for k, v in pairs(spec or {}) do
    grid[k] = v
  end
  return grid
end

function M.cell(v)
  if v == nil then
    return ""
  end
  if Psql.is_null(v) then
    return "NULL"
  end
  v = v:gsub("\r?\n", " ↵ "):gsub("\t", " ")
  return text.truncate(v, MAX_CELL, "…")
end

function M.full(v)
  if v == nil then
    return ""
  end
  if Psql.is_null(v) then
    return "NULL"
  end
  return (v:gsub("\r?\n", " ↵ "))
end

function M.slice(grid)
  local all = grid.all or {}
  local page = S.page_size
  grid.total = #all
  if grid.offset >= grid.total then
    grid.offset = math.max(0, math.floor((grid.total - 1) / page) * page)
  end
  local rows = {}
  for i = grid.offset + 1, math.min(grid.offset + page, grid.total) do
    rows[#rows + 1] = all[i]
  end
  grid.rows = rows
  if grid.sel > #rows then
    grid.sel = math.max(#rows, 1)
  end
end

function M.set_result(grid, result)
  grid.columns = result and result.columns or {}
  grid.all = result and result.rows or {}
  grid.offset = 0
  grid.sel = 1
  M.slice(grid)
end

local function select_row(grid, i)
  grid.sel = i
end

local function show_row(grid, title, i)
  grid.sel = i
  local row = grid.rows[i]
  if not row then
    return
  end
  local entries = {}
  for c, name in ipairs(grid.columns) do
    entries[c] = { key = name, value = M.full(row[c]) }
  end
  ttt.show_info(title .. " · row " .. tostring(grid.offset + i), entries)
end

local function change_page(grid, offset)
  grid.offset = offset
  grid.sel = 1
  if grid.all then
    M.slice(grid)
    S.redraw()
  elseif grid.on_page then
    grid.on_page(offset)
  end
end

local function pager(grid, h)
  h:pager({ offset = grid.offset, limit = S.page_size, total = grid.total, on_change = U.bind(change_page, grid) })
end

-- Columns without a width fit their widest cell, up to MAX_WIDTH, and longer
-- cells end in an ellipsis. The last column keeps that width as its minimum
-- and grows into the space left; columns that add up to more than the table
-- scroll sideways. Returns the columns and the clipped rows.
function M.fit(columns, rows)
  local out = {}
  for i, col in ipairs(columns) do
    local w = col.width
    if not w then
      w = text.width(col.label)
      for _, cells in ipairs(rows) do
        w = math.max(w, text.width(cells[i] or ""))
      end
      w = math.min(math.max(w, 4), MAX_WIDTH)
    end
    out[i] = { label = col.label, width = w, align = col.align }
  end
  local last = out[#out]
  local grows = last and not columns[#columns].width
  local clipped = {}
  for r, cells in ipairs(rows) do
    local line = {}
    for i, col in ipairs(out) do
      line[i] = (grows and i == #out) and (cells[i] or "") or text.truncate(cells[i] or "", col.width, "…")
    end
    clipped[r] = line
  end
  if grows then
    last.min_width, last.width = last.width, nil
  end
  return out, clipped
end

function M.render(p, grid, opts)
  local rows, styles = {}, {}
  for i, row in ipairs(grid.rows) do
    local cells = {}
    for c = 1, #grid.columns do
      cells[c] = M.cell(row[c])
    end
    rows[i] = cells
    styles[i] = "default"
  end
  local columns = {}
  for i, name in ipairs(grid.columns) do
    columns[i] = { label = name }
  end
  columns, rows = M.fit(columns, rows)
  p:table({
    inset = 1,
    columns = columns,
    rows = rows,
    row_styles = styles,
    selected = grid.sel,
    loading = grid.loading,
    empty = grid.err and "Couldn't load rows" or (opts.empty or "No rows"),
    on_select = U.bind(select_row, grid),
    on_activate = U.bind(show_row, grid, opts.title or "Row"),
  })
  p:divider()
  p:hstack({ height = 1, align = "center", render = U.bind(pager, grid) })
end

return M
