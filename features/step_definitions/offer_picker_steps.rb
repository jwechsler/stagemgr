Given(/^there is a flex pass offer named "([^"]*)" tagged "([^"]*)"$/) do |offer_name, tag|
  step %(there is a flex pass offer named "#{offer_name}")
  FlexPassOffer.find_by!(name: offer_name).flex_pass_offer_tags.create!(name: tag)
end

Given(/^there is an inactive flex pass offer named "([^"]*)"$/) do |offer_name|
  FactoryBot.create(:flex_pass_offer, name: offer_name, active: false, on_sale_to_public: false)
end

When(/^I search the offer picker in "([^"]*)" for "([^"]*)"$/) do |selector, term|
  within(selector) do
    find('.offer-picker-input').set(term)
  end
end

When(/^I choose "([^"]*)" from the offer picker suggestions$/) do |label|
  expect(page).to have_css('ul.ui-autocomplete li', text: label, wait: 5)
  page.find('ul.ui-autocomplete li', text: label).click
end

When(/^I remove "([^"]*)" from the offer picker in "([^"]*)"$/) do |label, selector|
  within(selector) do
    row = find('.offer-picker-table tr', text: label)
    row.find('.offer-picker-remove').click
  end
end

Then(/^the offer picker in "([^"]*)" should list "([^"]*)"$/) do |selector, label|
  within(selector) do
    expect(find('.offer-picker-table', visible: :all)).to have_text(label)
  end
end

Then(/^the offer picker in "([^"]*)" should list nothing$/) do |selector|
  within(selector) do
    expect(page).to have_no_css('.offer-picker-table tr')
  end
end

Then(/^I should see no offer picker suggestions$/) do
  expect(page).to have_no_css('ul.ui-autocomplete li', wait: 3)
end
