local storage = require("ttt.storage")

local S = {}

local saved = storage.get("connection")
S.saved = saved ~= nil
saved = saved or {}
S.conn = {
  uri = saved.uri or "",
  host = saved.host or "localhost",
  port = saved.port or "5432",
  database = saved.database or "postgres",
  user = saved.user or "postgres",
  password = saved.password or "",
}
S.settings = storage.get("settings") or {}
S.psql_path = S.settings.psql_path or "psql"
S.page_size = tonumber(S.settings.page_size) or 50

S.status = "idle"
S.message = ""
S.server = nil
S.gen = 0

S.schemas = {}
S.schema = storage.get("schema") or "public"
S.relations = {}
S.relations_loading = false
S.relations_err = nil
S.relations_gen = 0
S.filter = ""

S.panels = {}
S.active_query = nil

function S.redraw()
  for _, p in pairs(S.panels) do
    pcall(p.redraw, p)
    return
  end
end

function S.configured()
  return S.saved
end

return S
