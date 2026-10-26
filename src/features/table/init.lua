local U = require("core.util")
local Router = require("app.router")
local Store = require("features.table.store")
local Page = require("features.table.page")

local M = {}

M.store = Store
M.page = Page

-- Opens a table or view in its own tab, or focuses it when it is open.
function M.open(schema, name, kind)
  local rel = Store.relation(schema, name, kind)
  Router.show("table:" .. rel.key, U.bind(Page.page, rel))
end

return M
