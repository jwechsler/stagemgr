def enter_patron_information
  begin
    puts "Using admin interface?: #{@using_admin_interface}"

    # Try to detect if we're in the admin interface or the public interface
    if @using_admin_interface
      # Admin interface uses "Name" field
      if page.has_field?("Name", disabled: false)
        fill_in "Name", :with => "Ticket Buyer"
      elsif page.has_css?('.full_name')
        # Try looking for full_name field using autocomplete class
        find('.full_name').set("Ticket Buyer")
      elsif page.has_css?('#ticket_order_address_attributes_full_name')
        # Try direct ID
        find('#ticket_order_address_attributes_full_name').set("Ticket Buyer")
      else
        # Last resort - try to find by label
        find('label', text: 'Name').find(:xpath, '..').find('input').set("Ticket Buyer")
      end

      if page.has_field?("Email", disabled: false)
        fill_in "Email", :with => "test@theaterwit.org"
      elsif page.has_css?('.email')
        find('.email').set("test@theaterwit.org")
      end

      if page.has_field?("Phone", disabled: false)
        fill_in "Phone", :with => "555-555-1212"
      end

      # Try to fill in address fields
      if page.has_css?('fieldset.fieldset legend', text: 'Billing Address')
        within(find('fieldset.fieldset legend', text: 'Billing Address').find(:xpath, '..')) do
          if page.has_field?("Street", disabled: false)
            fill_in "Street", :with => "1229 W Belmont"
          end
          if page.has_field?("City", disabled: false)
            fill_in "City", :with => "Chicago"
          end
          if page.has_field?("State", disabled: false)
            fill_in "State", :with => "IL"
          end
          if page.has_field?("Zip/Postal", disabled: false)
            fill_in "Zip/Postal", :with => "60657"
          end
        end
      end
    else
      # Public interface uses "Your Name" field
      fill_in "Your Name", :with => "Ticket Buyer"
      fill_in "Email", :with => "test@theaterwit.org"
      fill_in "Street Address", :with => "1229 W Belmont"
      fill_in "City", :with => "Chicago"
      fill_in "State", :with => "IL"
      fill_in "Zip", :with => "60657"
      fill_in "Phone", :with => "555-555-1212"
    end
  rescue => e
    puts "Error filling in form: #{e.message}"
    puts "Available form fields:"
    field_labels = page.all('label').map(&:text)
    puts field_labels.inspect
    puts "Field IDs:"
    field_ids = page.all('input, select, textarea').map { |f| [f[:id], f[:name]].compact.join(', ') }.reject(&:empty?)
    puts field_ids.inspect
    puts "Page HTML: #{page.html}"
  end
end

When /^I place the order$/ do
  click_link('Place Order')
  page.driver.browser.switch_to.alert.accept
end

When('I submit the order') do
  accept_confirm do
    click_button("Place Order")
  end
end

Given /^I create a ticket order$/ do
  fill_in "ticket_order_production_code", :with => "ABC12"
  fill_in "ticket_order_performance_code", :with => "PERF"
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with => "A"
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with => "2"
  enter_patron_information
  select "Cash", :from => "ticket_order_payment_type"
  click_button "Place Order"
end

When /^I enter my contact information$/ do
  enter_patron_information
end

When /^I enter my contact information incorrectly$/ do
  enter_patron_information
  fill_in "Email", :with => ''
  fill_in "Street Address", :with => ''
end

Given /^I enter a gift recipient$/ do
  fill_in "Recipient name", :with => "Gift Getter"
  fill_in "Recipient email", :with => "test@theaterwit.org"
  fill_in :membership_order_gift_date, :with => Date.today
end

When /^I prefer "(.*?)" seating$/ do |seating_preference|
  select seating_preference, :from => "Preferred Seating"
end

When /^I enter a valid credit card as payment through the backend?$/ do
  @_current_form = 'ticket_order' if @_current_form.blank?

  select "Credit Card", from: "#{@_current_form}_payment_type_id"
  select 'bogus', from: "#{@_current_form}_credit_card_type"
  # select "Visa", :from=>"#{@_current_form}_credit_card_type"
  fill_in "#{@_current_form}_credit_card_expiration_month", :with => "01"
  fill_in "#{@_current_form}_credit_card_expiration_year", :with => (Date.today.year + 1).to_s[2..3]
  fill_in 'Credit card number', :with => "4111111111111111"
  fill_in "CVV", :with => "581"
end

Given("I enter a valid credit card as payment") do
  select 'Visa', from: "Card"
  # select "Visa", :from=>"#{@_current_form}_credit_card_type"
  select "01", from: "Month"
  select (Date.current.year + 1).to_s, from: "Year"
  fill_in 'Card #', :with => "4111111111111111"
  fill_in "CVV", :with => "581"
end

Given /^I choose "(.*?)" as payment$/ do |external_payment|
  select external_payment, :from => "Pay using"
end

Given /^I enter a check number "(.*?)" as payment$/ do |check_number|
  select "Check", :from => "Pay using"
  fill_in "Check number", :with => check_number
end

Given /^I enter flex pass( code)? "(.*?)" as payment$/ do |ignore, pass_code|
  @_current_form = 'ticket_order' if @_current_form.blank?
  if @using_admin_interface
    select "Flex Pass", :from => 'Pay using'
  else
    choose "Flex Pass"
  end
  fill_in "Flex pass code", :with => "#{pass_code}"
end

Given /^I enter (\d+) tickets for performance "(.*?)"$/ do |num_tix, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  @performance_code = perf_code
  ticket_class = performance.ticket_class_allocations.select { |tca| tca.ticket_class.web_visible }.first.ticket_class
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with => ticket_class.class_code
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with => num_tix
end

When /^I enter (\d+) "([^\"]*)" tickets$/ do |qty, ticket_class_code|
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with => ticket_class_code
  page.execute_script("document.getElementById('ticket_order_ticket_line_items_attributes_0_ticket_class_id').value='#{TicketClass.find_by(class_code: ticket_class_code).id}'")

  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with => qty
end

Given /^I enter an exchange for the order to performance "(.*?)"$/ do |perf_code|
  fill_in "ticket_order_performance_code", :with => perf_code
end

Then /^the payment option should include "(.*?)"$/ do |value|
  page.has_checked_field?('#ticket_order_payment_type_id', :with => value)
  # "//select[@id = 'ticket_order_payment_type_id']/option[text() = '#{value}']"
end

Then /^the payment option should not include "(.*?)"$/ do |value|
  page.should_not have_xpath "//select[@id = 'ticket_order_payment_type_id']/option[text() = '#{value}']"
end

Given(/^I mark the order as held under "(.*?)"$/) do |hold_under_name|
  fill_in "ticket_order_hold_under", :with => hold_under_name
end

Given('I enter {string} as an additional donation') do |string|
  fill_in "ticket_order_additional_donation", with: string
end

Given('I enter {string} as a visiting company donation') do |string|
  fill_in "ticket_order_additional_donation_for_other", with: string
end
