local U = require("core.util")
local S = require("core.state")
local Psql = require("core.psql")
local SQL = require("core.sql")
local UI = require("components")

local M = {}

M.relations = {}

function M.key(schema, name)
  return schema .. "." .. name
end

local function data_loaded(rel, gen, err, sets)
  local grid = rel.data
  if gen ~= grid.gen then
    return
  end
  grid.loading = false
  grid.loaded = true
  grid.err = err
  if err then
    grid.rows = {}
  else
    local count, page = sets[1], sets[2]
    grid.total = tonumber(count and count.rows[1] and count.rows[1][1]) or 0
    grid.columns = page and page.columns or {}
    grid.rows = page and page.rows or {}
    if grid.sel > #grid.rows then
      grid.sel = math.max(#grid.rows, 1)
    end
  end
  S.redraw()
end

function M.load_data(rel, offset)
  local grid = rel.data
  grid.offset = offset or grid.offset
  grid.gen = grid.gen + 1
  grid.loading = true
  S.redraw()
  Psql.query(SQL.page(rel.schema, rel.name, S.page_size, grid.offset), U.bind(data_loaded, rel, grid.gen))
end

local function rows_of(set)
  return set and set.rows or {}
end

local function structure_loaded(rel, gen, err, sets)
  local st = rel.structure
  if gen ~= st.gen then
    return
  end
  st.loading = false
  st.loaded = true
  st.err = err
  if not err then
    local info = rows_of(sets[1])[1] or {}
    st.info = { relkind = info[1], size = info[2], estimate = tonumber(info[3]), comment = info[4], viewdef = info[5] }
    st.columns = rows_of(sets[2])
    st.constraints = rows_of(sets[3])
    st.indexes = rows_of(sets[4])
    st.referenced_by = rows_of(sets[5])
  end
  S.redraw()
end

function M.load_structure(rel)
  local st = rel.structure
  st.gen = st.gen + 1
  st.loading = true
  S.redraw()
  Psql.query(SQL.structure(rel.schema, rel.name), U.bind(structure_loaded, rel, st.gen))
end

function M.relation(schema, name, kind)
  local key = M.key(schema, name)
  local rel = M.relations[key]
  if not rel then
    rel = {
      key = key,
      schema = schema,
      name = name,
      kind = kind or "table",
      data = UI.grid.new({ gen = 0 }),
      structure = { gen = 0, loaded = false, loading = false },
    }
    rel.data.on_page = U.bind(M.load_data, rel)
    M.relations[key] = rel
  end
  return rel
end

function M.forget(key)
  M.relations[key] = nil
end

function M.reload_all()
  for _, rel in pairs(M.relations) do
    rel.data.offset = 0
    rel.data.loaded = false
    rel.structure.loaded = false
  end
end

return M
