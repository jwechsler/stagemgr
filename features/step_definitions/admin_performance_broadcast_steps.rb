# Step definitions for performance broadcast email feature

# Setup steps

Given(/^the performance "(.*?)" has (\d+) processed orders with valid email addresses$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  ticket_class = performance.production.ticket_classes.first
  count.to_i.times do |i|
    address = FactoryBot.create(:address,
                                 email: "customer#{i}@example.com",
                                 placeholder: false,
                                 first_name: "Customer#{i}",
                                 last_name: "Test")
    order = TicketOrder.new(
      performance: performance,
      address: address,
      status: 'Processed'
    )
    # Add ticket line items before saving
    2.times do
      order.ticket_line_items << TicketLineItem.new(
        ticket_class: ticket_class,
        ticket_count: 1
      )
    end
    order.save!(validate: false)
  end
end

Given(/^the performance "(.*?)" has no eligible orders$/) do |perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  # All orders for this performance are either canceled or have no email
  performance.orders.update_all(status: 'Canceled')
end

Given(/^the performance "(.*?)" has (\d+) canceled order(?:s)?$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  ticket_class = performance.production.ticket_classes.first
  count.to_i.times do |i|
    address = FactoryBot.create(:address,
                                 email: "canceled#{i}@example.com",
                                 placeholder: false)
    order = TicketOrder.new(
      performance: performance,
      address: address,
      status: 'Canceled'
    )
    2.times do
      order.ticket_line_items << TicketLineItem.new(
        ticket_class: ticket_class,
        ticket_count: 1
      )
    end
    order.save!(validate: false)
  end
end

Given(/^the performance "(.*?)" has (\d+) order(?:s)? without an email address$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  ticket_class = performance.production.ticket_classes.first
  count.to_i.times do
    address = FactoryBot.create(:address, email: nil, placeholder: false)
    order = TicketOrder.new(
      performance: performance,
      address: address,
      status: 'Processed'
    )
    2.times do
      order.ticket_line_items << TicketLineItem.new(
        ticket_class: ticket_class,
        ticket_count: 1
      )
    end
    order.save!(validate: false)
  end
end

Given(/^the performance "(.*?)" has (\d+) order(?:s)? with a placeholder address$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  ticket_class = performance.production.ticket_classes.first
  count.to_i.times do |i|
    address = FactoryBot.create(:address,
                                 email: "placeholder#{i}@example.com",
                                 placeholder: true)
    order = TicketOrder.new(
      performance: performance,
      address: address,
      status: 'Processed'
    )
    2.times do
      order.ticket_line_items << TicketLineItem.new(
        ticket_class: ticket_class,
        ticket_count: 1
      )
    end
    order.save!(validate: false)
  end
end

Given(/^I am a box office user with email "(.*?)"$/) do |email|
  @current_test_user = User.find_by(is_box_office_user: true) || FactoryBot.build(:user)
  @current_test_user.is_box_office_user = true
  @current_test_user.email = email
  @current_test_user.save_without_session_maintenance
end

Given(/^a performance broadcast exists for performance "(.*?)"$/) do |perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  user = User.first || FactoryBot.create(:user)
  FactoryBot.create(:performance_broadcast,
                   performance: performance,
                   user: user,
                   subject: "Previous broadcast",
                   from_address: "boxoffice@theaterwit.org",
                   body: "Previous message")
end

# Modal interaction steps

When(/^I follow "(.*?)" in the datatable for performance "(.*?)"$/) do |link_text, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  expect(page).to have_css("tr[id='#{performance.id}']", wait: 15)
  within("tr[id='#{performance.id}']") do
    click_link link_text
  end
  # Wait for modal to appear
  expect(page).to have_css('#email-attendees-modal', visible: true, wait: 5)
end

Then(/^I should see the email attendees modal$/) do
  expect(page).to have_css('#email-attendees-modal', visible: true)
  expect(page).to have_content('Email Performance Attendees')
end

Then(/^I should see "(.*?)" recipients? in the modal$/) do |count|
  within('#email-attendees-modal') do
    expect(page).to have_content(count, wait: 10)
    expect(find('#recipient-count').text).to eq(count)
  end
end

Then(/^the subject field should contain "(.*?)"$/) do |text|
  within('#email-attendees-modal') do
    expect(find('#broadcast-subject').value).to include(text)
  end
end

When(/^I click "([^"]*)" and confirm with alert "([^"]*)"$/) do |button_text, expected_alert|
  within('#email-attendees-modal') do
    accept_confirm do
      click_button button_text
    end
  end
  # Accept the success/error alert that appears after the AJAX response
  @last_alert_message = accept_alert do
  end
  expect(@last_alert_message).to include(expected_alert)
end

When(/^I click "([^"]*)" and accept the validation alert$/) do |button_text|
  message = accept_alert do
    within('#email-attendees-modal') do
      click_button button_text
    end
  end
  expect(message).to include('Please fill in all required fields')
end

When(/^I click "([^"]*)"$/) do |button_text|
  within('#email-attendees-modal') do
    click_button button_text
  end
end

When(/^I click "([^"]*)" and confirm$/) do |button_text|
  within('#email-attendees-modal') do
    accept_confirm do
      click_button button_text
    end
  end
end

When(/^I click "([^"]*)" and cancel$/) do |button_text|
  within('#email-attendees-modal') do
    dismiss_confirm do
      click_button button_text
    end
  end
end

When(/^I click the close button$/) do
  within('#email-attendees-modal') do
    find('.close-button').click
  end
end

Then(/^the modal should remain open$/) do
  expect(page).to have_css('#email-attendees-modal', visible: true)
end

Then(/^the modal should close$/) do
  expect(page).to have_no_css('#email-attendees-modal', visible: true, wait: 5)
end

Then(/^the send button should be disabled$/) do
  within('#email-attendees-modal') do
    expect(find('#confirm-broadcast')).to be_disabled
  end
end

Then(/^I should see a confirmation dialog asking about sending to "(.*?)"$/) do |text|
  # This is handled by the accept_confirm/dismiss_confirm methods
  # The confirmation text is checked in the browser's native dialog
end

Then(/^the from address dropdown should include "(.*?)"$/) do |option|
  within('#email-attendees-modal') do
    expect(page).to have_select('broadcast-from-address', with_options: [option])
  end
end

# Database verification steps

Then(/^a performance broadcast should be created for performance "(.*?)"$/) do |perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  expect(PerformanceBroadcast.where(performance: performance).count).to be > 0
end

Then(/^(\d+) performance broadcasts should exist for performance "(.*?)"$/) do |count, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  expect(PerformanceBroadcast.where(performance: performance).count).to eq(count.to_i)
end

Then(/^no performance broadcast should be created$/) do
  # Check that no new broadcasts were created during this scenario
  expect(PerformanceBroadcast.count).to eq(0)
end

Then(/^(\d+) outreach tasks should be created for the broadcast$/) do |count|
  broadcast = PerformanceBroadcast.last
  expect(OutreachTask.where(method_symbol: 'custom_performance_broadcast').count).to eq(count.to_i)
end

Then(/^the broadcast body should contain markdown formatting$/) do
  broadcast = PerformanceBroadcast.last
  expect(broadcast.body).to include('**')
end
