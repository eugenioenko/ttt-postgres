local U = require("core.util")
local UI = require("components")
local Store = require("features.table.store")

local M = {}

local KIND = { r = "Table", p = "Partitioned table", f = "Foreign table", v = "View", m = "Materialized view" }
local CONTYPE = { p = "primary key", f = "foreign key", u = "unique", c = "check", x = "exclusion", t = "trigger" }

local COLUMN_COLUMNS = {
  { label = "#", width = 3, align = "right" },
  { label = "Name" },
  { label = "Type" },
  { label = "Null", width = 8 },
  { label = "Default" },
  { label = "Key", width = 6 },
}

local INDEX_COLUMNS = {
  { label = "Name" },
  { label = "Kind", width = 8 },
  { label = "Size", width = 10, align = "right" },
  { label = "Definition" },
}

local FK_COLUMNS = { { label = "Name" }, { label = "Definition" } }
local REF_COLUMNS = { { label = "Table" }, { label = "Name" }, { label = "Definition" } }
local CONSTRAINT_COLUMNS = { { label = "Name" }, { label = "Type", width = 10 }, { label = "Definition" } }

local function section_table(columns, rows, empty, b)
  local fitted, cells = UI.grid.fit(columns, rows)
  b:table({ inset = 1, columns = fitted, rows = cells, empty = empty })
end

local function section(p, title, columns, rows, empty)
  UI.frame(
    p,
    title .. "  " .. tostring(#rows),
    U.bind(section_table, columns, rows, empty),
    { height = math.max(#rows, 1) + 5, margin_top = 1 }
  )
end

local function definition_lines(lines, b)
  for _, line in ipairs(lines) do
    b:label({ text = line, style = "code", padding_left = 1 })
  end
end

local function view_definition(p, text)
  local lines = U.split(U.trim(text), "\n")
  UI.frame(p, "Definition", U.bind(definition_lines, lines), { height = #lines + 3, margin_top = 1 })
end

local function split_constraints(st)
  local pk, fks, others = nil, {}, {}
  for _, c in ipairs(st.constraints or {}) do
    if c[2] == "p" then
      pk = c[3]
    elseif c[2] == "f" then
      fks[#fks + 1] = { c[1], c[3] }
    else
      others[#others + 1] = { c[1], CONTYPE[c[2]] or c[2], c[3] }
    end
  end
  return pk, fks, others
end

local function column_rows(st)
  local rows = {}
  for i, c in ipairs(st.columns or {}) do
    rows[i] = { tostring(i), c[1], c[2], c[3], UI.grid.cell(c[4]), c[5] }
  end
  return rows
end

local function index_rows(st)
  local rows = {}
  for i, ix in ipairs(st.indexes or {}) do
    rows[i] = { ix[1], ix[3], ix[4], ix[2] }
  end
  return rows
end

local function ref_rows(st)
  local rows = {}
  for i, r in ipairs(st.referenced_by or {}) do
    rows[i] = { r[1], r[2], r[3] }
  end
  return rows
end

local function body(rel, sv)
  local st = rel.structure
  local info = st.info or {}
  local pk, fks, others = split_constraints(st)
  local is_view = info.relkind == "v" or info.relkind == "m"
  local estimate = info.estimate and info.estimate >= 0 and U.count(info.estimate) or "not analyzed"
  local kv = { { "Kind", KIND[info.relkind] or info.relkind } }
  if info.relkind ~= "v" then
    kv[#kv + 1] = { "Estimated rows", estimate }
    kv[#kv + 1] = { "Total size", info.size }
  end
  if not is_view then
    kv[#kv + 1] = { "Primary key", pk or "none" }
  end
  if info.comment and info.comment ~= "" then
    kv[#kv + 1] = { "Comment", info.comment }
  end
  sv:keyvalue(UI.kv(kv))
  section(sv, "Columns", COLUMN_COLUMNS, column_rows(st), "No columns")
  if is_view and info.viewdef ~= "" then
    view_definition(sv, info.viewdef)
  end
  if info.relkind ~= "v" then
    section(sv, "Indexes", INDEX_COLUMNS, index_rows(st), "No indexes")
  end
  if not is_view then
    section(sv, "Foreign keys", FK_COLUMNS, fks, "No foreign keys")
    section(sv, "Referenced by", REF_COLUMNS, ref_rows(st), "No foreign keys point here")
    section(sv, "Other constraints", CONSTRAINT_COLUMNS, others, "No unique, check or exclusion constraints")
  end
end

function M.render(p, rel)
  local st = rel.structure
  if not st.loaded and not st.loading then
    Store.load_structure(rel)
  end
  if st.err then
    UI.error_box(p, "Couldn't load the structure", st.err)
    return
  end
  if not st.loaded then
    UI.status(p, "Loading…")
    return
  end
  p:scrollview({ render = U.bind(body, rel) })
end

return M
