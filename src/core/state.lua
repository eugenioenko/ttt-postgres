local storage = require("ttt.storage")
local Saved = require("core.saved")

local S = {}

local function default_conn()
  return { uri = "", host = "localhost", port = "5432", database = "postgres", user = "postgres", password = "" }
end

S.default_conn = default_conn
S.entry = Saved.load()
S.conn = S.entry and Saved.conn(S.entry) or default_conn()
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
  return Saved.ready(S.entry)
end

return S
