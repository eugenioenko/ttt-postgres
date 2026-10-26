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

M.on_change = nil

local function save(v, done)
  local path = U.trim(v.psql_path)
  if path == "" then
    path = "psql"
  end
  S.psql_path = path
  S.page_size = tonumber(v.page_size) or S.page_size
  S.settings.psql_path = path
  S.settings.page_size = S.page_size
  storage.set("settings", S.settings)
  if M.on_change then
    M.on_change()
  end
  done()
end

function M.dialog()
  UI.dialog({
    title = "PostgreSQL Settings",
    width = 64,
    hint = "A path other than psql must also be in system.exec.",
    fields = {
      { key = "psql_path", label = "psql binary", value = S.psql_path, required = true, placeholder = "psql" },
      {
        key = "page_size",
        label = "Page size",
        kind = "enum",
        options = M.PAGE_SIZES,
        value = tostring(S.page_size),
      },
    },
    on_submit = save,
  })
end

return M
