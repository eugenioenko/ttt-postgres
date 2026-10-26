local U = {}

function U.trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

-- A plain-text split; string.gmatch crashes inside ttt callbacks.
function U.split(s, sep)
  local out, start = {}, 1
  s = s or ""
  while true do
    local i = s:find(sep, start, true)
    if not i then
      out[#out + 1] = s:sub(start)
      return out
    end
    out[#out + 1] = s:sub(start, i - 1)
    start = i + #sep
  end
end

function U.lines(s)
  local out = {}
  for _, line in ipairs(U.split(s or "", "\n")) do
    if U.trim(line) ~= "" then
      out[#out + 1] = line
    end
  end
  return out
end

function U.ident(name)
  return '"' .. tostring(name):gsub('"', '""') .. '"'
end

function U.literal(s)
  return "'" .. tostring(s):gsub("'", "''") .. "'"
end

function U.qualified(schema, name)
  return U.ident(schema) .. "." .. U.ident(name)
end

function U.count(n)
  n = tonumber(n)
  if not n or n < 0 then
    return ""
  end
  if n >= 1e9 then
    return string.format("%.1fG", n / 1e9)
  elseif n >= 1e6 then
    return string.format("%.1fM", n / 1e6)
  elseif n >= 1e4 then
    return string.format("%.0fk", n / 1e3)
  elseif n >= 1e3 then
    return string.format("%.1fk", n / 1e3)
  end
  return tostring(math.floor(n))
end

function U.plural(n, one, many)
  return tostring(n) .. " " .. (n == 1 and one or (many or one .. "s"))
end

function U.option_label(options, value)
  for _, o in ipairs(options) do
    if o.value == value then
      return o.label
    end
  end
  return "Select…"
end

-- Bound arguments come first, then the caller's.
function U.bind(fn, ...)
  local bound = { n = select("#", ...), ... }
  return function(...)
    local n = select("#", ...)
    local args = { unpack(bound, 1, bound.n) }
    for i = 1, n do
      args[bound.n + i] = select(i, ...)
    end
    return fn(unpack(args, 1, bound.n + n))
  end
end

return U
