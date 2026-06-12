Given(/^I enter a special feature called "(.*?)" with a description of "(.*?)"$/) do |short_name, desc|
  fill_in "special_feature_short_name", :with => short_name
  fill_in "special_feature_description", :with => "description"
end
