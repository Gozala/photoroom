return function(source, properties)
  local result = {}
  for name, value in pairs(source) do
    result[name] = value
  end
  for name, value in pairs(properties) do
    result[name] = value
  end
  return result
end
