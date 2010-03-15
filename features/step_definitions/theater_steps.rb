Then /^each theater name is a link to a theater detail page$/ do
  Theater.all.each do |theater|
    Given "I should see a link to '/admin/theaters/#{theater.id}' labeled '#{theater.name}'"
  end
end

Then /^I should see the logo for "([^\"]*)"$/ do |theater_name|
  path = Theater.find_by_name(theater_name).logo.url
  path = Capybara::XPath.send(:s, path)
  page.should have_xpath("//img[@src=#{path}]")
end