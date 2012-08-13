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
    new_object = FactoryGirl.create(symbol)
    eval "@#{type.underscore} = new_object"
  end

end

Given /^all the ticket class are available for Performance "([^"]*)"$/ do |performance_code|
  Performance.find_by_performance_code(performance_code).ticket_class_allocations.each do |tca|
    tca.available = true
    tca.save!
  end
end

Given /^a theater "(.*?)" exists$/ do |name|
  @theater = FactoryGirl.create(:theater,:name=>name)
end

Given /^(\d?) venues? exists?/ do |venue_count|
  venue_count.to_i.times do
    FactoryGirl.create(:venue)
  end
end

Given /^a?\s?venue "(.*?)" exists$/ do |venue|
  @venue = FactoryGirl.create(:venue, :name=>venue)
end

Given /^a production "(.*?)" exists$/ do |name|
  @production = FactoryGirl.create(:production, :name=>name, :theater=>@theater)
end

When /^a production "([^"]*)" exists for the theater "([^"]*)"$/ do |name, theater_name|
  @theater = Theater.find_by_name(theater_name)
  @production = FactoryGirl.create(:production, :name=>name, :code=>name[0..3].upper, :theater=>@theater)
end

When /^a donation of "\$(.*)" exists$/ do |amount|
  @donation = FactoryGirl.create(:donation_order)
  @donation.donation_line_items << FactoryGirl.create(:donation_line_item, :donation_amount=>amount)
  @donation.transition_to!(Order::PROCESSED)
end
