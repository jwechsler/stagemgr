Given /^the following ([^\"]*) exist:$/ do |type, table|
  symbol = type.underscore.singularize.to_sym
  table.hashes.each do |hash|
    new_object = Factory(symbol, hash)
  end
end

Given /^a(?:|n) ([^\"]*) exists$/ do |type|
  symbol = type.underscore.to_sym
  Factory(symbol)
end
  
  