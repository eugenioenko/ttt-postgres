local ttt = require("ttt")
local fs = require("ttt.fs")

local SUITES = { "util_test", "parse_test", "saved_test", "psql_test" }

local function same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for k, v in pairs(a) do
    if not same(v, b[k]) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end
  return true
end

local function show(v)
  if type(v) ~= "table" then
    return string.format("%q", tostring(v))
  end
  local parts = {}
  for k, x in pairs(v) do
    parts[#parts + 1] = tostring(k) .. "=" .. show(x)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

local t = {}

function t.eq(got, want, what)
  if not same(got, want) then
    error((what or "value") .. ": got " .. show(got) .. ", want " .. show(want), 2)
  end
end

function t.ok(v, what)
  if not v then
    error((what or "condition") .. " is false", 2)
  end
end

local function run_all()
  local lines, failed, passed = {}, 0, 0
  for _, suite in ipairs(SUITES) do
    for _, case in ipairs(require(suite)) do
      local ok, err = pcall(case[2], t)
      if ok then
        passed = passed + 1
        lines[#lines + 1] = "ok   " .. suite .. ": " .. case[1]
      else
        failed = failed + 1
        lines[#lines + 1] = "FAIL " .. suite .. ": " .. case[1] .. ": " .. tostring(err)
      end
    end
  end
  lines[#lines + 1] = string.format("%d passed, %d failed", passed, failed)
  fs.write(ttt.plugin_dir() .. "/results.txt", table.concat(lines, "\n") .. "\n")
end

ttt.register({ commands = { { id = "pgtests.run", title = "Postgres Tests: Run", handler = run_all } } })
