Then /^each theater name is a link to a page to edit the theater record$/ do
  Theater.all.each do |theater|
    Given "I should see a link to '/theaters/#{theater.id}/edit' labeled '#{theater.name}'"
  end
end

Then /^I should see the logo for "([^\"]*)"$/ do |theater_name|
  path = Theater.find_by_name(theater_name).logo.url
  path = Capybara::XPath.send(:s, path)
  page.should have_xpath("//img[@src=#{path}]")
end