local Parse = require("core.parse")

local US, RS, NULL = "\31", "\30", "\29"

local SAMPLE = "ttt-postgres backend 42 1700000000.5\n"
  .. ("id" .. US .. "name" .. RS)
  .. ("1" .. US .. "a" .. RS)
  .. ("2" .. US .. "" .. RS)
  .. ("3" .. US .. NULL .. RS)
  .. ("4" .. US .. "multi\nline" .. RS)
  .. "(4 rows)\n"
  .. "Time: 1.5 ms\n"
  .. "UPDATE 3\n"
  .. "Time: 0,25 ms\n"
  .. ("x" .. RS .. "(1 row)" .. RS .. "(1 row)\n")
  .. "Time: 0.1 ms\n"
  .. ("a" .. RS .. "(0 rows)\n")

local function feed_in(data, size, max_rows)
  local p = Parse.new(max_rows)
  for i = 1, #data, size do
    Parse.feed(p, data:sub(i, i + size - 1))
  end
  return p, Parse.finish(p)
end

local function whole(t)
  local p, list = feed_in(SAMPLE, #SAMPLE)
  t.eq(p.backend, { pid = 42, started = "1700000000.5" }, "backend")
  t.eq(#list, 4, "statements")
  t.eq(list[1].result.columns, { "id", "name" }, "columns")
  t.eq(list[1].result.rows, { { "1", "a" }, { "2", "" }, { "3", NULL }, { "4", "multi\nline" } }, "rows")
  t.eq(list[1].result.complete, true, "complete")
  t.eq(list[1].ms, 1.5, "ms")
  t.eq(list[2].tag, "UPDATE 3", "tag")
  t.eq(list[2].ms, 0.25, "decimal comma")
  t.eq(list[3].result.rows, { { "(1 row)" } }, "a value that looks like a footer")
  t.eq(list[4].result.total, 0, "empty result")
  t.eq(list[4].result.complete, true, "empty result complete")
end

local function chunked(t)
  local _, want = feed_in(SAMPLE, #SAMPLE)
  for size = 1, #SAMPLE do
    local _, got = feed_in(SAMPLE, size)
    t.eq(got, want, "chunks of " .. size)
  end
end

local function long_value(t)
  local value = string.rep("0123456789", 20000)
  local data = "v" .. RS .. value .. RS .. "(1 row)\n"
  local _, list = feed_in(data, 65536)
  t.eq(#list[1].result.rows[1][1], #value, "value length")
  t.eq(list[1].result.complete, true, "complete")
end

local function capped(t)
  local p, list = feed_in(SAMPLE, 7, 2)
  t.eq(#list[1].result.rows, 2, "kept")
  t.eq(list[1].result.total, 4, "counted")
  t.eq(list[1].result.complete, true, "footer still found")
  t.eq(p.received, 5, "received")
end

local function unfinished(t)
  local cut = SAMPLE:find("3" .. US, 1, true) + 1
  local _, list = feed_in(SAMPLE:sub(1, cut), 5)
  t.eq(list[1].result.rows, { { "1", "a" }, { "2", "" } }, "partial record dropped")
  t.eq(list[1].result.complete, false, "incomplete")
end

local function no_trailing_newline(t)
  local _, list = feed_in("DELETE 2", 3)
  t.eq(list[1].tag, "DELETE 2")
end

return {
  { "separators, NULL, empty strings, tags and timing", whole },
  { "same result for every chunk size", chunked },
  { "a value longer than a chunk", long_value },
  { "rows past max_rows are counted, not kept", capped },
  { "output that stops inside a result set", unfinished },
  { "last line without a newline", no_trailing_newline },
}
