Given /^the following ([^\"]*) exist(?:| on the ([a-zA-Z]+) "([^\"]*)"):$/ do |type, parent_type, parent_name, table|
  symbol = type.underscore.singularize.to_sym
  parent = parent_type.constantize.find_by_name(parent_name) if parent_type
  
  table.hashes.each do |hash|
    if parent_type
      hash.merge!({"#{parent_type.downcase}_id".to_sym=>parent.id})
    end
    without_access_control do
      new_object = FactoryGirl.create(symbol, hash)
    end
  end
end

Given /^a(?:|n) ([^\"]*) exists$/ do |type|
  symbol = type.underscore.to_sym
  without_access_control do
    FactoryGirl.create!(symbol)
  end
end

Given /^all the ticket class are available for Performance "([^"]*)"$/ do |performance_code|
  Performance.find_by_performance_code(performance_code).ticket_class_allocations.each do |tca|
    tca.available = true
    tca.save!
  end
end


  