local Psql = require("core.psql")

local function has(list, value)
  for _, v in ipairs(list) do
    if v:find(value, 1, true) then
      return true
    end
  end
  return false
end

local function target_fields(t)
  local conninfo, pw =
    Psql.target({ uri = "", host = "h", port = "5432", database = "o'k", user = "u", password = "s3" })
  t.ok(conninfo:find("dbname='o\\'k'", 1, true), "quoted dbname in " .. conninfo)
  t.ok(not conninfo:find("s3", 1, true), "no password in the conninfo")
  t.eq(pw, "s3", "password")
  t.ok(not has(Psql.args(conninfo), "s3"), "no password in the arguments")
end

local function target_uri(t)
  local conninfo, pw = Psql.target({ uri = "postgresql://u:pw@h/db", password = "" })
  t.eq(conninfo, "postgresql://u@h/db", "uri")
  t.eq(pw, "pw", "password from the uri")
  conninfo, pw = Psql.target({ uri = "postgresql://u:pw@h/db", password = "typed" })
  t.eq(pw, "typed", "typed password wins")
end

return {
  { "fields become a conninfo without the password", target_fields },
  { "a uri keeps its password out of the command line", target_uri },
}
