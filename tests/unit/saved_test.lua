local storage = require("ttt.storage")
local Saved = require("core.saved")

local function uri_userinfo(t)
  local uri, pw = Saved.split_uri("postgresql://u:p%40ss@h:5432/db?sslmode=require")
  t.eq(uri, "postgresql://u@h:5432/db?sslmode=require", "uri")
  t.eq(pw, "p@ss", "password")
end

local function uri_parameter(t)
  local uri, pw = Saved.split_uri("postgresql://u@h/db?password=x&sslmode=require")
  t.eq(uri, "postgresql://u@h/db?sslmode=require", "uri")
  t.eq(pw, "x", "password")
end

local function keywords(t)
  local conninfo, pw = Saved.split_uri("host=h password='a b' user=u")
  t.eq(conninfo, "host=h user=u", "quoted")
  t.eq(pw, "a b", "quoted password")
  conninfo, pw = Saved.split_uri("password=secret host=h")
  t.eq(conninfo, "host=h", "unquoted")
  t.eq(pw, "secret", "unquoted password")
end

local function no_password(t)
  local uri, pw = Saved.split_uri("postgresql://u@h/db")
  t.eq(uri, "postgresql://u@h/db", "uri")
  t.eq(pw, nil, "password")
end

local function default_name(t)
  Saved.list = {}
  t.eq(Saved.default_name({ host = "h", database = "db", uri = "" }), "db@h")
  t.eq(Saved.default_name({ uri = "postgresql://u@host1:5432/mydb" }), "mydb@host1")
  Saved.list = { { name = "db@h" } }
  t.eq(Saved.default_name({ host = "h", database = "db", uri = "" }), "db@h 2", "taken")
  t.eq(Saved.default_name({ host = "h", database = "db", uri = "" }, "db@h"), "db@h", "renaming itself")
end

local function session_password(t)
  Saved.session = {}
  local entry = { name = "x", save_password = false }
  t.eq(Saved.ready(entry), false, "asks first")
  Saved.session.x = ""
  t.eq(Saved.ready(entry), true, "empty session password")
  t.eq(Saved.password({ name = "y", save_password = true, password = "pw" }), "pw", "saved")
end

local function migration(t)
  Saved.list = {}
  storage.remove("connections")
  storage.remove("active")
  storage.set("connection", {
    uri = "postgresql://u:pw@h/db",
    host = "localhost",
    port = "5432",
    database = "postgres",
    user = "postgres",
    password = "",
  })
  local entry = Saved.load()
  t.eq(entry.name, "db@h", "name")
  t.eq(entry.uri, "postgresql://u@h/db", "password left the uri")
  t.eq(entry.password, "pw", "password kept")
  t.eq(entry.save_password, true, "saved, as before")
  t.eq(storage.get("connection"), nil, "old key removed")
  t.eq(storage.get("active"), "db@h", "active")
  t.eq(#storage.get("connections"), 1, "stored")
end

return {
  { "password in the uri's user info", uri_userinfo },
  { "password as a uri parameter", uri_parameter },
  { "password in a key=value string", keywords },
  { "uri without a password", no_password },
  { "default names", default_name },
  { "session passwords", session_password },
  { "the old single connection migrates", migration },
}
