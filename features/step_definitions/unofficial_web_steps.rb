Given /^I debug stuff$/ do
  require 'ruby-debug'
  debugger 
  a=1
end

Given /^I follow "([^\"]*)" "([^\"]*)" link$/ do |label, nondescript_link|
  within(:xpath, Capybara::XPath.wrap("//a[contains(.,'#{label}')]/../..")) do
    click_link(nondescript_link)
  end
end

Given /^(?:|I )should (|not )see a link(?:| to '([^']+)')(?:| labeled '([^']+)')$/ do |is_not,path,link_label|
  begin
    if(is_not=='not ')
      if path.nil?
        assert page.has_no_xpath?(Capybara::XPath.link(link_label))
      elsif link_label.nil?
        path = Capybara::XPath.send(:s, path)
        assert page.has_no_xpath?(Capybara::XPath.wrap("//a[@href=#{path}]"))
      else
        link_label = Capybara::XPath.send(:s, link_label)
        path = Capybara::XPath.send(:s, path)
        assert page.has_no_xpath?(Capybara::XPath.wrap("//a[@href=#{path}][@id=#{link_label} or contains(.,#{link_label}) or contains(@title,#{link_label})]"))
      end
    else
      if path.nil?
        assert page.has_xpath?(Capybara::XPath.link(link_label))
      elsif link_label.nil?
        path = Capybara::XPath.send(:s, path)
        assert page.has_xpath?(Capybara::XPath.wrap("//a[@href=#{path}]"))
      else
        link_label = Capybara::XPath.send(:s, link_label)
        path = Capybara::XPath.send(:s, path)
        assert page.has_xpath?(Capybara::XPath.wrap("//a[@href=#{path}][@id=#{link_label} or contains(.,#{link_label}) or contains(@title,#{link_label})]"))
      end
    end
  rescue Test::Unit::AssertionFailedError => e
    save_and_open_page
    raise
  end
end

Given /^I select ([0-9]+\/[0-9]+\/[0-9]+) from "([^\"]*)"$/ do |date, field|
  parent_of_date = locate(:xpath, "//label[contains(.,'#{field}')]")['for']
  date = Date.parse(date)
  Given "I select \"#{date.year}\" from \"#{parent_of_date}_1i\""
  Given "I select \"#{Date::MONTHNAMES[date.month]}\" from \"#{parent_of_date}_2i\""
  Given "I select \"#{date.day}\" from \"#{parent_of_date}_3i\""
end

When /^I attach the test file "([^\"]*)" to "([^\"]*)"$/ do |filename, field|
  path = Rails.root.join('test','files',filename).to_s
  attach_file(field, path)
end
