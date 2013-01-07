return function(...)
  -- Returns a vector representing the concatenation of the elements in the
  -- supplied vectors.
  local sequences = {...}
  local result = {}
  for _, sequence in ipairs(sequences) do
    for _, item  in ipairs(sequence) do result[#result + 1] = item end
  end
  return result
end
