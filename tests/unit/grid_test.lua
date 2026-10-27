local ttt = require("ttt")
local Grid = require("components.grid")
local Psql = require("core.psql")

local function aligned_values(t)
  t.eq(Grid.row_lines({ "id", "名字", "é" }, { "42", "東京", "value" }), {
    "id    42",
    "名字  東京",
    "é    value",
  })
end

local function full_values(t)
  local long = string.rep("x", 1000)
  t.eq(
    Grid.row_lines({ "value", "value", "empty", "null", "missing", "long" }, {
      "first\r\n\n  second\tpart\n",
      "9223372036854775807",
      "",
      Psql.NULL,
      nil,
      long,
    }),
    {
      "value    first",
      "         ",
      "           second\tpart",
      "         ",
      "value    9223372036854775807",
      'empty    ""',
      "null     NULL",
      "missing  NULL",
      "long     " .. long,
    }
  )
end

local function row_actions(t)
  local spec
  local panel = {
    table = function(_, opts)
      spec = opts
    end,
    divider = function() end,
    hstack = function() end,
  }
  local grid = Grid.new({ columns = { "id" }, rows = { { "42" }, { "43" } }, offset = 50 })
  Grid.render(panel, grid, { title = "users" })
  local opened = {}
  local original = ttt.open_readonly
  ttt.open_readonly = function(title, lines)
    opened[#opened + 1] = { title, lines }
  end
  local good, err = pcall(function()
    spec.on_command("view", 1)
    spec.on_activate(2)
    spec.on_activate(3)
  end)
  ttt.open_readonly = original
  t.ok(good, err)
  t.eq(opened, {
    { "users · row 51", { "id  42" } },
    { "users · row 52", { "id  43" } },
  })
end

return {
  { "aligns values by display width, including wide and combining characters", aligned_values },
  { "preserves multiline, long and precise values, duplicate columns, nulls and empty strings", full_values },
  { "View and Enter open readonly row snapshots with page-relative titles", row_actions },
}
