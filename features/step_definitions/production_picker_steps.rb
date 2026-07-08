When(/^I search the production picker in "([^"]*)" for "([^"]*)"$/) do |selector, term|
  within(selector) do
    find('.production-picker-input').set(term)
  end
end

When(/^I choose "([^"]*)" from the production picker suggestions$/) do |label|
  expect(page).to have_css('ul.ui-autocomplete li', text: label, wait: 5)
  page.find('ul.ui-autocomplete li', text: label).click
end

Then(/^the production picker in "([^"]*)" should show "([^"]*)"$/) do |selector, label|
  within(selector) do
    expect(find('.production-picker-label')).to have_text(label)
  end
end

When(/^I search the production multi picker in "([^"]*)" for "([^"]*)"$/) do |selector, term|
  within(selector) do
    find('.production-multi-picker-input').set(term)
  end
end

Then(/^the production multi picker in "([^"]*)" should list "([^"]*)"$/) do |selector, label|
  within(selector) do
    expect(find('.production-multi-picker-table', visible: :all)).to have_text(label)
  end
end
