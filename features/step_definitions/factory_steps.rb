Given /^the following ([^\"]*) exist:$/ do |type, table|
    symbol = type.gsub(' ', '_').singularize.to_sym
    table.hashes.each do |hash|
      new_object = Factory(symbol, hash)
    end
end