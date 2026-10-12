Then(/^the "([^"]*)" button should be disabled$/) do |label|
  expect(page).to have_button(label, disabled: true)
end
