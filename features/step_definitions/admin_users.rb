Given (/^a theater user "(.*?)" exists$/) do |username|
  user = FactoryBot.create(:user, email: username)
  user.theaters << Theater.first
  user.save
end

Given (/^I set the status to "(.*?)"$/) do |arg1|
  select "Inactive", :from=>"Status"
end

Given (/^I sign in as user "(.*?)" with password "(.*?)"$/) do |email, password|
  fill_in :Email, :with=>email
  fill_in :Password, :with=>password
  click_button "Login"
end
