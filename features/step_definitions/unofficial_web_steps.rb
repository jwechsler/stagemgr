Given(/^I debug stuff$/) do
  require 'ruby-debug'
  debugger
  1
end

# this needs to be reimplmented
# Given /^I follow "([^\"]*)" "([^\"]*)" link$/ do |label, nondescript_link|
#  within(:xpath, Capybara::XPath.wrap("//a[contains(.,'#{label}')]/../..")) do
#    click_link(nondescript_link)
#  end
# end

Then(/^['"]([^"]*)['"] should link to ['"]([^"]*)"(?: within "([^"]*)")$/) do |link_text,
page_name, container|
  with_scope(container) do
    URI.parse(page.find_link(link_text)['href']).path.should == path_to(page_name)
  end
end

Then(/^a link exists to "(.*?)"$/) do |arg1|
  page.should have_xpath("//a[@href='" + arg1 + "']")
end

# Given /^(?:|I )should (|not )see a link(?:| to '([^']+)')(?:| labeled '([^']+)')$/ do |is_not,path,link_label|
#   begin
#     if(is_not=='not ')
#       if path.nil?
#         assert page.has_no_xpath?(Capybara::XPath.link(link_label))
#       elsif link_label.nil?
#         path = Capybara::XPath.send(:s, path)
#         assert page.has_no_xpath?(Capybara::XPath.wrap("//a[@href=#{path}]"))
#       else
#         link_label = Capybara::XPath.send(:s, link_label)
#         path = Capybara::XPath.send(:s, path)
#         assert page.has_no_xpath?(Capybara::XPath.wrap("//a[@href=#{path}][@id=#{link_label} or contains(.,#{link_label}) or contains(@title,#{link_label})]"))
#       end
#     else
#       if path.nil?
#         assert page.has_xpath?(Capybara::XPath.link(link_label))
#       elsif link_label.nil?
#         path = Capybara::XPath.send(:s, path)
#         assert page.has_xpath?(Capybara::XPath.wrap("//a[@href=#{path}]"))
#       else
#         link_label = Capybara::XPath.send(:s, link_label)
#         path = Capybara::XPath.send(:s, path)
#         assert page.has_xpath?(Capybara::XPath.wrap("//a[@href=#{path}][@id=#{link_label} or contains(.,#{link_label}) or contains(@title,#{link_label})]"))
#       end
#     end
#   rescue Test::Unit::AssertionFailedError => e
#     save_and_open_page
#     raise
#   end
# end

Given(/^I change "(.*?)" to "(.*?)"$/) do |field, value|
  fill_in(field, with: value)
end

Given(%r{^I select ([0-9]+/[0-9]+/[0-9]+) from "([^"]*)"$}) do |date, field|
  parent_of_date = find(:xpath, "//label[contains(.,'#{field}')]")['for']
  parent_of_date.gsub!('_1i', '')
  select_date_by_id(date, parent_of_date)
end

When(/^I attach the test file "([^"]*)" to "([^"]*)"$/) do |filename, field|
  path = Rails.root.join('test', 'files', filename).to_s
  attach_file(field, path)
end
Then(/^["']([^"]*)['"] should link to ['"]([^"]*)['"]$/) do |link_text, page_name|
  URI.parse(page.find_link(link_text)['href']).path.should == path_to(page_name)
end

Then(/^"([^"]*)" should not link to "([^"]*)"$/) do |link_text, page_name|
  URI.parse(page.find_link(link_text)['href']).path.should != path_to(page_name)
end
