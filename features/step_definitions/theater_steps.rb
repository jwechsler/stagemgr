Then(/^each theater name is a link to a theater detail page$/) do
  Theater.all.each do |theater|
    step "'#{theater.name}' should link to 'the admin detail page for theater '#{theater.name}''"
  end
end

# Then /^I should see the logo for "([^\"]*)"$/ do |theater_name|
#   path = Theater.find_by_name(theater_name).logo.url
#   path = Capybara::XPath.send(:s, path)
#   page.should have_xpath("//img[@src=#{path}]")
# end
