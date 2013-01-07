function reduce(table, f, initial)
  local result = initial
  for key, value in pairs(table) do result = f(result, value, key) end
  return result
end

return reduce
