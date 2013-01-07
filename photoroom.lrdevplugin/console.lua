local info = require("Info")
local logger = import("LrLogger")

local log = logger(info.LrPluginName)
log:enable("print")

function serialize(input, indent)
  if not indent then indent = 0 end

  if type(input) == "table" then
    local result = "{\n"
    for key, value in pairs(input) do
      result = result
            .. string.rep("  ", indent + 1)
            .. key
            .. " = "
            .. serialize(value, indent + 1)
            .. ",\n"
    end
    return result .. string.rep("  ", indent) .. "}"
  elseif type(input) == "string" then
    return '"' .. input .. '"'
  else
    return tostring(input)
  end
end

return {
  log = function(input) log:info("\n" .. serialize(input)) end,
  info = function(input) log:info("\n" .. serialize(input)) end,
  debug = function(input) log:debug("\n" .. serialize(input)) end,
  error = function(input) log:error("\n" .. serialize(input)) end,
  warn = function(input) log:warn("\n" .. serialize(input)) end,
  trace = function(input) log:trace("\n" .. serialize(input)) end
}
