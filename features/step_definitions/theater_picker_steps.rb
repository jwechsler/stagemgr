When(/^I search the theater multi picker in "([^"]*)" for "([^"]*)"$/) do |selector, term|
  within(selector) do
    find('.theater-multi-picker-input').set(term)
  end
end

Then(/^the theater multi picker in "([^"]*)" should list "([^"]*)"$/) do |selector, label|
  within(selector) do
    expect(page).to have_css('.theater-multi-picker-table td', text: label, wait: 5)
  end
end

Then(/^the theater multi picker in "([^"]*)" should not list "([^"]*)"$/) do |selector, label|
  within(selector) do
    expect(page).to have_no_css('.theater-multi-picker-table td', text: label)
  end
end
