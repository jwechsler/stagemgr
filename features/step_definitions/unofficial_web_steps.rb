Given /^(?:|I )should (|not )see a link (?:|to '(.+)' )labeled '(.+)'$/ do |is_not,path,link_label|
  if(is_not=='not ')
    if path.nil?
      assert page.has_no_xpath?(Capybara::XPath.link(link_label))
    else
      link_label = Capybara::XPath.send(:s, link_label)
      path = Capybara::XPath.send(:s, path)
      assert page.has_no_xpath?(Capybara::XPath.wrap("//a[@href=#{path}][@id=#{link_label} or contains(.,#{link_label}) or contains(@title,#{link_label})]"))
    end
  else
    save_and_open_page unless page.has_xpath?(Capybara::XPath.link(link_label))
    if path.nil?
      assert page.has_xpath?(Capybara::XPath.link(link_label))
    else
      link_label = Capybara::XPath.send(:s, link_label)
      path = Capybara::XPath.send(:s, path)
      assert page.has_xpath?(Capybara::XPath.wrap("//a[@href=#{path}][@id=#{link_label} or contains(.,#{link_label}) or contains(@title,#{link_label})]"))
    end
  end
end

When /^I attach the test file "([^\"]*)" to "([^\"]*)"$/ do |filename, field|
  path = Rails.root.join('test','files',filename).to_s
  attach_file(field, path)
end
