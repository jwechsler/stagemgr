Given /^the following (.*) exists?(?:| on the ([a-zA-Z]+) "([^\"]*)"):$/ do |type, parent_type, parent_name, table|
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

Given /^all the ticket class are available for Performance "([^\"]*)"$/ do |performance_code|
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

Given /^a membership offer "(.*?)" exists$/ do |offer_name|
  @membership_offer = FactoryGirl.create(:membership_offer, :name=>offer_name)
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


Then /^the order should have an email task$/ do
  @order = Order.last
  count = @order.tasks.select{|task| task.is_a? MyEmmaTask}.size
  raise "Expected one email task, got #{count}" if count != 1
end

Then /^an? membership order exists for "(.*?)"$/ do |name|
  raise "No order found for #{name}" if Order.includes(:address).where('addresses.full_name = ?', name).count == 0
end


Then /^a membership exists with status "(.*?)"$/ do |status|
  count = Membership.count
  raise "More than one membership found" if count > 1
  raise "No memberships created" if count == 0
  membership = Membership.find_by_status(status)
  raise "No such membership \"#{status}\" found.  Found only #{Membership.all.map { |m| m.status}.join(',')}" if membership.nil?
end


Then /^a membership exists with current status "(.*?)"$/ do |status|
  count = Membership.count
  raise "More than one membership found" if count > 1
  raise "No membership with current status \"#{status} found" unless Membership.all.select{|m| m.current_status == status }.count == 1
end

Then /^a membership order exists with a gift recipient "(.*?)"$/ do |name|
  order = MembershipOrder.find_by_recipient_name(name)
  raise "No membership with gift recipient \"#{name}\" found. Only found #{Address.all.map{|a| a.full_name}}" if order.nil?;
end

Then /^an address "(.*?)" exists$/ do |name|
  Address.where('full_name = ?',name).count == 1
end

Then /^a membership_offer should exist with trial_period of (\d+)$/ do |period|
  MembershipOffer.find_all_by_trial_period(period).count == 1
end

Then /^a membership exists with "(.*?)" as preferred seating$/ do |preferred_seating|
  raise "Found #{Membership.find_all_by_preferred_seating(preferred_seating).count} memberships with #{preferred_seating} preferred seating" unless Membership.find_all_by_preferred_seating(preferred_seating).count == 1
end



