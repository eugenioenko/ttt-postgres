local U = require("core.util")

local function thousands(t)
  t.eq(U.thousands(0), "0")
  t.eq(U.thousands(999), "999")
  t.eq(U.thousands(1000), "1,000")
  t.eq(U.thousands(1234567), "1,234,567")
end

local function split(t)
  t.eq(U.split("a\31b\31", "\31"), { "a", "b", "" })
  t.eq(U.split("", ","), { "" })
end

local function plural(t)
  t.eq(U.plural(1, "row"), "1 row")
  t.eq(U.plural(10000, "row"), "10,000 rows")
end

return {
  { "thousands separators", thousands },
  { "split keeps empty fields", split },
  { "plural", plural },
}
