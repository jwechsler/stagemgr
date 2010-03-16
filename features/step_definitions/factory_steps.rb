Given /^the following ([^\"]*) exist(?: on the ([a-zA-Z]+) "([^\"]*)"):$/ do |type, parent_type, parent_name, table|
  symbol = type.underscore.singularize.to_sym
  parent = parent_type.constantize.find_by_name(parent_name) if parent_type
  
  table.hashes.each do |hash|
    new_object = Factory(symbol, hash)
    if parent_type
      parent.send("#{type}") << new_object
    end
  end
end

Given /^a(?:|n) ([^\"]*) exists$/ do |type|
  symbol = type.underscore.to_sym
  Factory(symbol)
end
  
  