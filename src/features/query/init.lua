local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local Router = require("app.router")
local Store = require("features.query.store")
local Page = require("features.query.page")

local M = {}

function M.new(sql, run)
  local q = Store.new(sql)
  Router.show("query:" .. q.id, U.bind(Page.page, q), true)
  if run then
    Store.run(q)
  end
  return q
end

function M.open_with(sql)
  M.new(sql, true)
end

function M.run_active()
  if S.active_query then
    Store.run(S.active_query)
  else
    ttt.notify("Open a query tab first: Postgres: New Query", "warn")
  end
end

return M
